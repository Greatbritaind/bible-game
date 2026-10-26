// JavaScript half of the RGSS runtime: bitmaps, the screen renderer, fonts, keyboard and sound.
// Ruby calls these through `window.RGSS` (see src/ruby/rgss.rb).
import type { GameFiles } from "./gamefs";
import { CTL, KEYS_CAPACITY, SCREEN_MAX_PIXELS, TEXT_CAPACITY, type SharedBuffers, type ToPage } from "./shared";

type Canvas = OffscreenCanvas;
type Ctx = OffscreenCanvasRenderingContext2D;

interface Bmp {
  canvas: Canvas;
  ctx: Ctx;
  w: number;
  h: number;
  /** Increases whenever the bitmap's pixels change (for the tinted-sprite cache) */
  ver: number;
}

interface ViewportRec {
  kind: "V";
  id: number;
  visible: boolean;
  z: number;
  x: number;
  y: number;
  w: number;
  h: number;
  ox: number;
  oy: number;
  color: number[];
  tone: number[];
  flash: number[];
  children: Set<Drawable>;
}

interface SpriteRec {
  kind: "S";
  id: number;
  vp: number;
  bmp: number;
  visible: boolean;
  x: number;
  y: number;
  z: number;
  ox: number;
  oy: number;
  zx: number;
  zy: number;
  angle: number;
  mirror: boolean;
  opacity: number;
  blend: number;
  sx: number;
  sy: number;
  sw: number;
  sh: number;
  color: number[];
  tone: number[];
  bush: number;
  bushOpacity: number;
  flash: number[];
}

interface PlaneRec {
  kind: "P";
  id: number;
  vp: number;
  bmp: number;
  visible: boolean;
  z: number;
  ox: number;
  oy: number;
  zx: number;
  zy: number;
  opacity: number;
  blend: number;
  color: number[];
  tone: number[];
}

type Drawable = SpriteRec | PlaneRec;
type TopLevel = Drawable | ViewportRec;

// All drawing happens in CPU memory: it keeps pixel reads (tones, transitions) cheap and avoids
// slow GPU round trips on low-end Chromebooks.
const newCanvas = (w: number, h: number): [Canvas, Ctx] => {
  const c = new OffscreenCanvas(Math.max(1, w), Math.max(1, h));
  const ctx = c.getContext("2d", { willReadFrequently: true })!;
  ctx.imageSmoothingEnabled = false;
  return [c, ctx];
};

const BLEND: GlobalCompositeOperation[] = ["source-over", "lighter", "difference"];

export class Engine {
  private bitmaps = new Map<number, Bmp>();
  private nextBitmap = 1;
  private imageCache = new Map<string, Canvas | null>();
  private objects = new Map<number, TopLevel>();
  private viewports = new Map<number, ViewportRec>();
  private screenChildren = new Set<TopLevel>();

  private width = 640;
  private height = 480;
  private back: Canvas;
  private backCtx: Ctx;
  private frozen: Canvas | null = null;
  private transitionMask: Uint8ClampedArray | null = null;
  private transitionVague = 40;
  private transitionProgress = -1;
  private brightness = 255;
  private scratch: [Canvas, Ctx];
  private scratch2: [Canvas, Ctx];

  private fontFamilies = new Map<string, string>(); // lower-case name -> CSS family
  private fontMetrics = new Map<string, { asc: number; desc: number; upm: number }>(); // CSS family -> hhea metrics
  private measure: Ctx;
  private out: [Canvas, Ctx];
  private ctl: Int32Array;
  private keys: Uint16Array;
  private text: Uint16Array;
  private decodeBuf: Uint8ClampedArray;
  private audioPos: Float64Array;
  private screenBuf: Uint8ClampedArray;
  private nextBuffer = 0;
  private lastFrame = 0;

  constructor(
    private files: GameFiles,
    shared: SharedBuffers,
    private post: (msg: ToPage, transfer?: Transferable[]) => void,
  ) {
    this.ctl = new Int32Array(shared.control);
    this.keys = new Uint16Array(shared.keys);
    this.text = new Uint16Array(shared.text);
    this.decodeBuf = new Uint8ClampedArray(shared.decode);
    this.audioPos = new Float64Array(shared.audioPos);
    this.screenBuf = new Uint8ClampedArray(shared.screen);
    [this.back, this.backCtx] = newCanvasRead(this.width, this.height);
    this.out = newCanvas(this.width, this.height);
    this.scratch = newCanvasRead(64, 64);
    this.scratch2 = newCanvasRead(64, 64);
    this.measure = newCanvas(8, 8)[1];
    this.resizeScreen(640, 480);
  }

  // ---------------------------------------------------------------- fonts
  async loadFonts() {
    for (const path of this.files.list("fonts/")) {
      if (!/\.(ttf|otf)$/i.test(path)) continue;
      const data = this.files.get(path)!;
      const names = fontNames(data);
      if (names.length === 0) continue;
      const css = "rgssfont_" + this.fontFamilies.size;
      try {
        const face = new FontFace(css, data.slice().buffer);
        await face.load();
        (self as unknown as { fonts: FontFaceSet }).fonts.add(face);
        for (const n of names) this.fontFamilies.set(n.toLowerCase(), css);
        const metrics = fontVerticalMetrics(data);
        if (metrics) this.fontMetrics.set(css, metrics);
      } catch (e) {
        console.warn("Font failed to load", path, e);
      }
    }
  }

  private family(names: string) {
    for (const n of names.split("|")) {
      const f = this.fontFamilies.get(n.toLowerCase());
      if (f) return f;
    }
    return "";
  }

  /**
   * Lay out text the way mkxp-z (SDL_ttf) does, so Essentials' hand-tuned text positions line up:
   * fonts are opened at 90% of the requested size, and the text's height covers the font's
   * nominal height plus any glyph parts that stick out above or below it.
   */
  private layout(str: string, names: string, size: number, bold: number, italic: number) {
    const family = this.family(names);
    const px = Math.max(1, Math.trunc(size * 0.9));
    const font = `${italic ? "italic " : ""}${bold ? "bold " : ""}${px}px ${family || "Arial, Helvetica, sans-serif"}`;
    const ctx = this.measure;
    ctx.font = font;
    const m = ctx.measureText(str || " ");
    const fm = family ? this.fontMetrics.get(family) : undefined;
    let ascent: number, nominal: number;
    if (fm) {
      const scale = px / fm.upm;
      ascent = Math.ceil(fm.asc * scale);
      nominal = Math.ceil((fm.asc - fm.desc) * scale);
    } else {
      ascent = Math.ceil(m.fontBoundingBoxAscent ?? px * 0.8);
      nominal = ascent + Math.ceil(m.fontBoundingBoxDescent ?? px * 0.2);
    }
    const top = str ? ascent - Math.ceil(m.actualBoundingBoxAscent) : 0;
    const bottom = str ? ascent + Math.ceil(m.actualBoundingBoxDescent) : nominal;
    const minY = Math.min(0, top);
    const maxY = Math.max(nominal, bottom);
    return { font, width: Math.ceil(m.width), height: maxY - minY, baseline: ascent - minY };
  }

  // ---------------------------------------------------------------- API for Ruby
  api() {
    // Arrow functions keep `this`; Ruby calls these by name.
    return {
      bmp_new: (w: number, h: number) => this.bmpNew(w, h),
      bmp_load: (path: string) => this.bmpLoad(path),
      bmp_clone: (id: number) => {
        const src = this.bitmaps.get(id);
        if (!src) return this.bmpNew(1, 1);
        const nid = this.bmpNew(src.w, src.h);
        this.bitmaps.get(nid)!.ctx.drawImage(src.canvas, 0, 0);
        return nid;
      },
      bmp_dispose: (id: number) => {
        this.bitmaps.delete(id);
      },
      bmp_blt: (
        dst: number,
        dx: number,
        dy: number,
        src: number,
        sx: number,
        sy: number,
        sw: number,
        sh: number,
        dw: number,
        dh: number,
        opacity: number,
      ) => {
        const d = this.bitmaps.get(dst);
        const s = this.bitmaps.get(src);
        if (!d || !s || sw === 0 || sh === 0 || dw === 0 || dh === 0 || opacity <= 0) return;
        // Clip the source rectangle to the bitmap like RGSS does
        let x0 = sx,
          y0 = sy,
          x1 = sx + sw,
          y1 = sy + sh;
        if (sw < 0) [x0, x1] = [x1, x0];
        if (sh < 0) [y0, y1] = [y1, y0];
        const cx0 = Math.max(0, x0),
          cy0 = Math.max(0, y0),
          cx1 = Math.min(s.w, x1),
          cy1 = Math.min(s.h, y1);
        if (cx1 <= cx0 || cy1 <= cy0) return;
        const scaleX = dw / sw,
          scaleY = dh / sh;
        const ctx = d.ctx;
        d.ver++;
        ctx.globalAlpha = Math.min(1, opacity / 255);
        ctx.drawImage(
          s.canvas,
          cx0,
          cy0,
          cx1 - cx0,
          cy1 - cy0,
          dx + (cx0 - sx) * scaleX,
          dy + (cy0 - sy) * scaleY,
          (cx1 - cx0) * scaleX,
          (cy1 - cy0) * scaleY,
        );
        ctx.globalAlpha = 1;
      },
      bmp_fill: (id: number, x: number, y: number, w: number, h: number, r: number, g: number, b: number, a: number) => {
        const bm = this.bitmaps.get(id);
        if (!bm || w <= 0 || h <= 0) return;
        bm.ver++;
        bm.ctx.clearRect(x, y, w, h);
        if (a > 0) {
          bm.ctx.fillStyle = `rgba(${r | 0},${g | 0},${b | 0},${a / 255})`;
          bm.ctx.fillRect(x, y, w, h);
        }
      },
      bmp_gradient: (id: number, x: number, y: number, w: number, h: number, c1: string, c2: string, vertical: number) => {
        const bm = this.bitmaps.get(id);
        if (!bm || w <= 0 || h <= 0) return;
        bm.ver++;
        const g = vertical ? bm.ctx.createLinearGradient(0, y, 0, y + h) : bm.ctx.createLinearGradient(x, 0, x + w, 0);
        g.addColorStop(0, csvColor(c1));
        g.addColorStop(1, csvColor(c2));
        bm.ctx.clearRect(x, y, w, h);
        bm.ctx.fillStyle = g;
        bm.ctx.fillRect(x, y, w, h);
      },
      bmp_clear: (id: number, x: number, y: number, w: number, h: number) => {
        const bm = this.bitmaps.get(id);
        if (!bm) return;
        bm.ver++;
        bm.ctx.clearRect(x, y, w, h);
      },
      bmp_get_pixel: (id: number, x: number, y: number) => {
        const bm = this.bitmaps.get(id);
        if (!bm) return 0;
        const [c, ctx] = this.scratchFor(1, 1);
        ctx.clearRect(0, 0, 1, 1);
        ctx.drawImage(bm.canvas, x, y, 1, 1, 0, 0, 1, 1);
        const d = ctx.getImageData(0, 0, 1, 1).data;
        void c;
        return ((d[0] << 24) | (d[1] << 16) | (d[2] << 8) | d[3]) >>> 0;
      },
      bmp_hue: (id: number, hue: number) => {
        const bm = this.bitmaps.get(id);
        if (!bm || hue % 360 === 0) return;
        bm.ver++;
        const [c, ctx] = this.scratchFor(bm.w, bm.h);
        ctx.clearRect(0, 0, bm.w, bm.h);
        ctx.filter = `hue-rotate(${hue}deg)`;
        ctx.drawImage(bm.canvas, 0, 0);
        ctx.filter = "none";
        bm.ctx.clearRect(0, 0, bm.w, bm.h);
        bm.ctx.drawImage(c, 0, 0, bm.w, bm.h, 0, 0, bm.w, bm.h);
      },
      bmp_blur: (id: number) => {
        const bm = this.bitmaps.get(id);
        if (!bm) return;
        bm.ver++;
        const [c, ctx] = this.scratchFor(bm.w, bm.h);
        ctx.clearRect(0, 0, bm.w, bm.h);
        ctx.filter = "blur(1px)";
        ctx.drawImage(bm.canvas, 0, 0);
        ctx.filter = "none";
        bm.ctx.clearRect(0, 0, bm.w, bm.h);
        bm.ctx.drawImage(c, 0, 0, bm.w, bm.h, 0, 0, bm.w, bm.h);
      },
      bmp_text: (
        id: number,
        x: number,
        y: number,
        w: number,
        h: number,
        str: string,
        align: number,
        names: string,
        size: number,
        bold: number,
        italic: number,
        color: string,
        outline: number,
        outColor: string,
        shadow: number,
      ) => this.drawText(id, x, y, w, h, str, align, names, size, bold, italic, color, outline, outColor, shadow),
      text_width: (str: string, names: string, size: number, bold: number, italic: number) =>
        this.layout(str, names, size, bold, italic).width,
      text_height: (str: string, names: string, size: number, bold: number, italic: number) =>
        this.layout(str, names, size, bold, italic).height,
      font_exists: (name: string) => (this.fontFamilies.has(name.toLowerCase()) ? 1 : 0),

      frame: (sync: string) => this.frame(sync),
      freeze: (sync: string) => {
        this.applySync(sync);
        this.render();
        const [c, ctx] = newCanvas(this.width, this.height);
        ctx.drawImage(this.back, 0, 0);
        this.frozen = c;
      },
      transition_begin: (filename: string, vague: number) => {
        this.transitionMask = null;
        this.transitionVague = Math.max(1, vague);
        if (filename) {
          const img = this.decode(filename);
          if (img) {
            const [, ctx] = newCanvasRead(this.width, this.height);
            ctx.drawImage(img, 0, 0, this.width, this.height);
            const d = ctx.getImageData(0, 0, this.width, this.height).data;
            const mask = new Uint8ClampedArray(this.width * this.height);
            for (let i = 0; i < mask.length; i++) mask[i] = d[i * 4];
            this.transitionMask = mask;
          }
        }
        this.transitionProgress = 0;
      },
      transition_progress: (p: number) => {
        this.transitionProgress = p;
      },
      transition_end: () => {
        this.transitionProgress = -1;
        this.frozen = null;
        this.transitionMask = null;
      },
      set_brightness: (b: number) => {
        this.brightness = b;
      },
      resize_screen: (w: number, h: number) => this.resizeScreen(w, h),
      snap_to_bitmap: (id: number, sync: string) => {
        this.applySync(sync);
        this.render();
        const bm = this.bitmaps.get(id);
        if (bm) bm.ver++;
        bm?.ctx.drawImage(this.back, 0, 0);
      },

      input_poll: () => this.pollInput(),
      set_clipboard: (t: string) => this.post({ type: "clipboard", text: t }),

      audio_play: (ch: string, name: string, vol: number, pitch: number, pos: number) =>
        this.post({ type: "audio", op: "play", ch, name, vol, pitch, pos }),
      audio_stop: (ch: string) => this.post({ type: "audio", op: "stop", ch }),
      audio_fade: (ch: string, ms: number) => this.post({ type: "audio", op: "fade", ch, ms }),
      audio_pos: (ch: string) => (ch === "bgs" ? this.audioPos[1] : this.audioPos[0]),

      set_title: (t: string) => this.post({ type: "title", title: t }),
      user_language: () => (navigator.language || "en-US").replace("-", "_"),
      message_box: (t: string) => {
        Atomics.store(this.ctl, CTL.MSGBOX_DONE, 0);
        this.post({ type: "msgbox", text: t });
        while (Atomics.load(this.ctl, CTL.MSGBOX_DONE) === 0) Atomics.wait(this.ctl, CTL.MSGBOX_DONE, 0, 1000);
      },
    };
  }

  // ---------------------------------------------------------------- bitmaps
  private bitmapBytes() {
    let n = 0;
    for (const b of this.bitmaps.values()) n += b.w * b.h * 4;
    return n;
  }

  private bmpNew(w: number, h: number) {
    const [canvas, ctx] = newCanvas(w, h);
    const id = this.nextBitmap++;
    this.bitmaps.set(id, { canvas, ctx, w, h, ver: 0 });
    return id;
  }

  /** Decode an image. The page does the decoding (fast, native) while this thread waits. */
  private decode(path: string): Canvas | null {
    const key = path.toLowerCase();
    if (this.imageCache.has(key)) return this.imageCache.get(key)!;
    const found = this.files.resolve(path, [".png", ".gif", ".jpg", ".jpeg", ".bmp"]);
    let img: Canvas | null = null;
    if (found) {
      Atomics.store(this.ctl, CTL.DECODE_DONE, 0);
      this.post({ type: "decode", path: found.path });
      while (Atomics.load(this.ctl, CTL.DECODE_DONE) === 0) Atomics.wait(this.ctl, CTL.DECODE_DONE, 0, 1000);
      const w = this.ctl[CTL.DECODE_W],
        h = this.ctl[CTL.DECODE_H];
      if (w > 0 && h > 0) {
        const [c, ctx] = newCanvas(w, h);
        const pixels = new ImageData(w, h);
        pixels.data.set(this.decodeBuf.subarray(0, w * h * 4));
        ctx.putImageData(pixels, 0, 0);
        img = c;
      }
    }
    // Keep decoded images so repeated loads are instant (graphics are reused a lot)
    this.imageCache.set(key, img);
    this.cacheBytes += img ? img.width * img.height * 4 : 0;
    while (this.cacheBytes > 96 * 1024 * 1024 && this.imageCache.size > 1) {
      const first = this.imageCache.keys().next().value!;
      const c = this.imageCache.get(first);
      this.cacheBytes -= c ? c.width * c.height * 4 : 0;
      this.imageCache.delete(first);
    }
    return img;
  }
  private cacheBytes = 0;

  private bmpLoad(path: string) {
    const img = this.decode(path);
    if (!img) return [0, 0, 0];
    const id = this.bmpNew(img.width, img.height);
    this.bitmaps.get(id)!.ctx.drawImage(img, 0, 0);
    return [id, img.width, img.height];
  }

  private scratchFor(w: number, h: number): [Canvas, Ctx] {
    const [c, ctx] = this.scratch;
    if (c.width < w || c.height < h) {
      c.width = Math.max(c.width, w);
      c.height = Math.max(c.height, h);
      ctx.imageSmoothingEnabled = false;
    }
    return this.scratch;
  }

  private drawText(
    id: number,
    x: number,
    y: number,
    w: number,
    h: number,
    str: string,
    align: number,
    names: string,
    size: number,
    bold: number,
    italic: number,
    color: string,
    outline: number,
    outColor: string,
    shadow: number,
  ) {
    const bm = this.bitmaps.get(id);
    if (!bm) return;
    bm.ver++;
    const ctx = bm.ctx;
    const t = this.layout(str, names, size, bold, italic);
    ctx.font = t.font;
    ctx.textBaseline = "alphabetic";
    let width = t.width;
    // Text too wide for the rectangle is squeezed, like RPG Maker does
    let squeeze = 1;
    if (width > w && w > 0) {
      squeeze = w / width;
      width = w;
    }
    let tx = x;
    if (align === 1) tx = x + Math.trunc((w - width) / 2);
    else if (align === 2) tx = x + w - width;
    const ty = y + Math.trunc((h - t.height) / 2) + t.baseline;
    ctx.save();
    ctx.translate(Math.round(tx), Math.round(ty));
    ctx.scale(squeeze, 1);
    if (shadow) {
      ctx.fillStyle = "rgba(0,0,0,0.5)";
      ctx.fillText(str, 1, 1);
    }
    if (outline) {
      ctx.strokeStyle = csvColor(outColor);
      ctx.lineWidth = 2;
      ctx.lineJoin = "round";
      ctx.strokeText(str, 0, 0);
    }
    ctx.fillStyle = csvColor(color);
    ctx.fillText(str, 0, 0);
    ctx.restore();
  }

  // ---------------------------------------------------------------- scene graph
  private applySync(sync: string) {
    if (!sync) return;
    for (const line of sync.split("\n")) {
      if (!line) continue;
      const [kind, idStr, rest] = line.split("|");
      const id = +idStr;
      if (kind === "X") {
        this.remove(id);
        continue;
      }
      const v = rest.split(",").map(Number);
      if (kind === "S") this.syncSprite(id, v);
      else if (kind === "P") this.syncPlane(id, v);
      else if (kind === "V") this.syncViewport(id, v);
    }
  }

  private parent(vp: number): Set<TopLevel> {
    if (vp === 0) return this.screenChildren;
    let v = this.viewports.get(vp);
    if (!v) {
      // Viewport not seen yet (created and used in the same frame) — create a placeholder
      v = {
        kind: "V", id: vp, visible: true, z: 0, x: 0, y: 0, w: this.width, h: this.height, ox: 0, oy: 0,
        color: [0, 0, 0, 0], tone: [0, 0, 0, 0], flash: [0, 0, 0, 0], children: new Set(),
      };
      this.viewports.set(vp, v);
      this.objects.set(vp, v);
      this.screenChildren.add(v);
    }
    return v.children as Set<TopLevel>;
  }

  private syncSprite(id: number, v: number[]) {
    let s = this.objects.get(id) as SpriteRec | undefined;
    if (s && s.vp !== v[0]) {
      this.parent(s.vp).delete(s);
    }
    if (!s) {
      s = { kind: "S", id } as SpriteRec;
      this.objects.set(id, s);
    }
    s.vp = v[0];
    s.bmp = v[1];
    s.visible = v[2] === 1;
    s.x = v[3];
    s.y = v[4];
    s.z = v[5];
    s.ox = v[6];
    s.oy = v[7];
    s.zx = v[8];
    s.zy = v[9];
    s.angle = v[10];
    s.mirror = v[11] === 1;
    s.opacity = v[12];
    s.blend = v[13];
    s.sx = v[14];
    s.sy = v[15];
    s.sw = v[16];
    s.sh = v[17];
    s.color = v.slice(18, 22);
    s.tone = v.slice(22, 26);
    s.bush = v[26];
    s.bushOpacity = v[27];
    s.flash = v.slice(28, 32);
    this.parent(s.vp).add(s);
  }

  private syncPlane(id: number, v: number[]) {
    let p = this.objects.get(id) as PlaneRec | undefined;
    if (p && p.vp !== v[0]) this.parent(p.vp).delete(p);
    if (!p) {
      p = { kind: "P", id } as PlaneRec;
      this.objects.set(id, p);
    }
    p.vp = v[0];
    p.bmp = v[1];
    p.visible = v[2] === 1;
    p.z = v[3];
    p.ox = v[4];
    p.oy = v[5];
    p.zx = v[6];
    p.zy = v[7];
    p.opacity = v[8];
    p.blend = v[9];
    p.color = v.slice(10, 14);
    p.tone = v.slice(14, 18);
    this.parent(p.vp).add(p);
  }

  private syncViewport(id: number, v: number[]) {
    let vp = this.viewports.get(id);
    if (!vp) {
      vp = { kind: "V", id, children: new Set() } as unknown as ViewportRec;
      this.viewports.set(id, vp);
      this.objects.set(id, vp);
      this.screenChildren.add(vp);
    }
    vp.visible = v[0] === 1;
    vp.z = v[1];
    vp.x = v[2];
    vp.y = v[3];
    vp.w = v[4];
    vp.h = v[5];
    vp.ox = v[6];
    vp.oy = v[7];
    vp.color = v.slice(8, 12);
    vp.tone = v.slice(12, 16);
    vp.flash = v.slice(16, 20);
  }

  private remove(id: number) {
    const o = this.objects.get(id);
    if (!o) return;
    this.objects.delete(id);
    if (o.kind === "V") {
      this.viewports.delete(id);
      this.screenChildren.delete(o);
      // Sprites still pointing at a disposed viewport stop drawing (like RGSS)
    } else {
      this.parent(o.vp).delete(o);
    }
  }

  // ---------------------------------------------------------------- rendering
  private resizeScreen(w: number, h: number) {
    this.width = w;
    this.height = h;
    this.back.width = w;
    this.back.height = h;
    this.backCtx.imageSmoothingEnabled = false;
    this.out[0].width = w;
    this.out[0].height = h;
    this.out[1].imageSmoothingEnabled = false;
  }

  private debugFrames = 0;
  private renderTime = 0;
  private frame(sync: string) {
    if ((self as unknown as { __debug?: boolean }).__debug && ++this.debugFrames % 120 === 0) {
      console.log(`[perf] average draw time ${(this.renderTime / 120).toFixed(2)} ms/frame, ${this.bitmaps.size} bitmaps (${Math.round(this.bitmapBytes() / 1048576)} MB), image cache ${Math.round(this.cacheBytes / 1048576)} MB, ruby memory ${Math.round(((self as unknown as { __rubyMemory?: () => number }).__rubyMemory?.() ?? 0) / 1048576)} MB`);
      if (this.debugFrames % 600 === 0) this.dumpScene();

      this.renderTime = 0;
    }
    const t = performance.now();
    this.applySync(sync);
    this.render();
    this.present();
    this.renderTime += performance.now() - t;
    // Copy the finished frame into shared memory (no new objects per frame, so memory stays flat)
    const w = this.width,
      h = this.height;
    if (w * h <= SCREEN_MAX_PIXELS) {
      const buffer = this.nextBuffer;
      this.nextBuffer ^= 1;
      this.screenBuf.set(this.out[1].getImageData(0, 0, w, h).data, buffer * SCREEN_MAX_PIXELS * 4);
      this.post({ type: "frame", buffer, width: w, height: h });
    }
    this.waitFrame();
  }

  private dumpScene() {
    const desc = (o: TopLevel): string => {
      if (o.kind === "V")
        return `V${o.id}[${o.visible ? "" : "hidden "}z${o.z} ${o.x},${o.y} ${o.w}x${o.h}${hasTone(o.tone) ? " tone" + o.tone : ""}${o.color[3] ? " color" + o.color : ""}: ${[...o.children].filter((c) => c.visible && c.opacity > 0 && this.bitmaps.has(c.bmp)).length}/${o.children.size} shown]`;
      return `${o.kind}${o.id}(${o.visible ? "" : "hidden "}b${o.bmp} o${o.opacity} ${"x" in o ? `@${o.x},${o.y} ${o.sw}x${o.sh}` : ""})`;
    };
    for (const v of this.viewports.values()) {
      if (v.children.size === 0) continue;
      console.log(`[scene] V${v.id} children: ` + [...v.children].sort(byZ).map((c) => `${c.kind}${c.id}{z${c.z} ${c.visible ? "" : "hidden "}b${c.bmp}${this.bitmaps.has(c.bmp) ? "" : "(missing)"} o${c.opacity} zoom${c.zx},${c.zy}${c.kind === "S" ? ` @${c.x},${c.y} src${c.sx},${c.sy},${c.sw}x${c.sh}` : ""}}`).join(" "));
    }
    console.log(`[scene] frozen=${!!this.frozen} bright=${this.brightness} bitmaps=${this.bitmaps.size} ` + [...this.screenChildren].sort(byZ).map(desc).join(" "));
  }

  /** Sleep until the page shows the next frame (about 1/60 s). */
  waitFrame() {
    let now = Atomics.load(this.ctl, CTL.FRAME);
    if (now === this.lastFrame) {
      Atomics.wait(this.ctl, CTL.FRAME, now, 100);
      now = Atomics.load(this.ctl, CTL.FRAME);
    }
    this.lastFrame = now;
    // While the tab is hidden, sleep instead of running the game at full speed
    while (Atomics.load(this.ctl, CTL.PAUSED) === 1) Atomics.wait(this.ctl, CTL.PAUSED, 1, 1000);
  }

  private pollInput() {
    let codes = "";
    for (let tries = 0; tries < 10; tries++) {
      const seq = Atomics.load(this.ctl, CTL.KEYS_SEQ);
      if (seq & 1) continue;
      const len = Math.min(Atomics.load(this.ctl, CTL.KEYS_LEN), KEYS_CAPACITY);
      codes = String.fromCharCode(...this.keys.subarray(0, len));
      if (Atomics.load(this.ctl, CTL.KEYS_SEQ) === seq) break;
    }
    let typed = "";
    const written = Math.min(Atomics.load(this.ctl, CTL.TEXT_LEN), TEXT_CAPACITY);
    const read = Atomics.load(this.ctl, CTL.TEXT_READ);
    if (written > read) {
      typed = String.fromCharCode(...this.text.subarray(read, written));
      Atomics.store(this.ctl, CTL.TEXT_READ, written);
    }
    const mouse = `${this.ctl[CTL.MOUSE_X]},${this.ctl[CTL.MOUSE_Y]},${this.ctl[CTL.MOUSE_IN]}`;
    return `${codes}\u0001${typed}\u0001${mouse}`;
  }

  private render() {
    const ctx = this.backCtx;
    ctx.globalAlpha = 1;
    ctx.globalCompositeOperation = "source-over";
    ctx.fillStyle = "#000";
    ctx.fillRect(0, 0, this.width, this.height);
    const top = [...this.screenChildren].filter((o) => o.visible).sort(byZ);
    for (const o of top) {
      if (o.kind === "V") this.drawViewport(ctx, o);
      else this.drawItem(ctx, o, 0, 0, this.width, this.height);
    }
  }

  private drawViewport(ctx: Ctx, vp: ViewportRec) {
    const x0 = Math.max(0, vp.x),
      y0 = Math.max(0, vp.y),
      x1 = Math.min(this.width, vp.x + vp.w),
      y1 = Math.min(this.height, vp.y + vp.h);
    if (x1 <= x0 || y1 <= y0) return;
    const children = [...vp.children].filter((o) => o.visible).sort(byZ);
    const effect = hasTone(vp.tone) || vp.color[3] > 0 || vp.flash[3] !== 0;
    ctx.save();
    ctx.beginPath();
    ctx.rect(x0, y0, x1 - x0, y1 - y0);
    ctx.clip();
    for (const o of children) {
      this.drawItem(ctx, o as Drawable, vp.x - vp.ox, vp.y - vp.oy, vp.w, vp.h, vp);
    }
    ctx.restore();
    if (effect) {
      const w = x1 - x0,
        h = y1 - y0;
      const img = this.backCtxRead().getImageData(x0, y0, w, h);
      const flash = vp.flash[3] > 0 ? vp.flash : vp.color;
      applyToneColor(img.data, vp.tone, flash, true);
      if (vp.flash[3] < 0) img.data.fill(0); // flash with no color hides the viewport
      this.backCtx.putImageData(img, x0, y0);
    }
  }

  private backCtxRead(): Ctx {
    // Reading pixels back is only needed when tones/colors are used
    return this.backCtx;
  }

  private drawItem(ctx: Ctx, o: Drawable, offX: number, offY: number, vw: number, vh: number, _vp?: ViewportRec) {
    if (o.kind === "S") this.drawSprite(ctx, o, offX, offY);
    else this.drawPlane(ctx, o, offX, offY, vw, vh, _vp);
  }

  private effectCache = new Map<string, Canvas>();
  private effectBytes = 0;

  private drawSprite(ctx: Ctx, s: SpriteRec, offX: number, offY: number) {
    if (s.opacity <= 0 || s.zx === 0 || s.zy === 0) return;
    const bm = this.bitmaps.get(s.bmp);
    if (!bm) return;
    // Clip the source rectangle to the bitmap
    const sx = Math.max(0, s.sx),
      sy = Math.max(0, s.sy);
    const sw = Math.min(bm.w, s.sx + s.sw) - sx,
      sh = Math.min(bm.h, s.sy + s.sh) - sy;
    if (sw <= 0 || sh <= 0) return;
    let source: CanvasImageSource = bm.canvas;
    let srcX = sx,
      srcY = sy;
    const flashing = s.flash[3] !== 0;
    const color = flashing ? s.flash : s.color;
    const needsEffect = hasTone(s.tone) || color[3] > 0 || (s.bush > 0 && s.bushOpacity < 255);
    if (flashing && s.flash[3] < 0) return; // flash with no color hides the sprite
    if (needsEffect) {
      // Tinted/colored copies are cached: map tiles share a few tileset pictures, and
      // recoloring them pixel by pixel every frame made walking around very slow.
      const bushRows = s.bush > 0 && s.bushOpacity < 255 ? Math.round(s.bush / Math.max(s.zy, 0.01)) : 0;
      const key = `${s.bmp}:${bm.ver}:${sx},${sy},${sw},${sh}:${s.tone}:${color}:${bushRows},${s.bushOpacity}`;
      let c = this.effectCache.get(key);
      if (c) {
        this.effectCache.delete(key); // keep recently used entries at the end
        this.effectCache.set(key, c);
      } else {
        let cctx: Ctx;
        [c, cctx] = newCanvasRead(sw, sh);
        cctx.drawImage(bm.canvas, sx, sy, sw, sh, 0, 0, sw, sh);
        const img = cctx.getImageData(0, 0, sw, sh);
        applyToneColor(img.data, s.tone, color, false);
        if (bushRows > 0) {
          const startRow = Math.max(0, sh - bushRows);
          const f = s.bushOpacity / 255;
          for (let yy = startRow; yy < sh; yy++) {
            for (let xx = 0; xx < sw; xx++) img.data[(yy * sw + xx) * 4 + 3] *= f;
          }
        }
        cctx.putImageData(img, 0, 0);
        this.effectCache.set(key, c);
        this.effectBytes += sw * sh * 4;
        while (this.effectBytes > 48 * 1024 * 1024 && this.effectCache.size > 1) {
          const [k, old] = this.effectCache.entries().next().value!;
          this.effectBytes -= old.width * old.height * 4;
          this.effectCache.delete(k);
        }
      }
      source = c;
      srcX = 0;
      srcY = 0;
    }
    ctx.save();
    ctx.translate(offX + s.x, offY + s.y);
    if (s.angle) ctx.rotate((-s.angle * Math.PI) / 180);
    ctx.scale(s.zx, s.zy);
    ctx.globalAlpha = s.opacity / 255;
    ctx.globalCompositeOperation = BLEND[s.blend] ?? "source-over";
    const dy = -s.oy + (sy - s.sy);
    if (s.mirror) {
      // Like RPG Maker: the picture flips inside its own rectangle (it doesn't move)
      const dx = -s.ox + (s.sx + s.sw - (sx + sw));
      ctx.translate(dx + sw, dy);
      ctx.scale(-1, 1);
      ctx.drawImage(source, srcX, srcY, sw, sh, 0, 0, sw, sh);
    } else {
      ctx.drawImage(source, srcX, srcY, sw, sh, -s.ox + (sx - s.sx), dy, sw, sh);
    }
    ctx.restore();
  }

  private scratchFor2(w: number, h: number): [Canvas, Ctx] {
    const [c, ctx] = this.scratch2;
    if (c.width < w || c.height < h) {
      c.width = Math.max(c.width, w);
      c.height = Math.max(c.height, h);
      ctx.imageSmoothingEnabled = false;
    }
    return this.scratch2;
  }

  private drawPlane(ctx: Ctx, p: PlaneRec, offX: number, offY: number, vw: number, vh: number, vp?: ViewportRec) {
    if (p.opacity <= 0) return;
    const bm = this.bitmaps.get(p.bmp);
    if (!bm || p.zx <= 0 || p.zy <= 0) return;
    const tw = bm.w * p.zx,
      th = bm.h * p.zy;
    // A plane covers its viewport (or the whole screen)
    const left = vp ? vp.x : 0,
      top = vp ? vp.y : 0;
    const startX = left - mod(p.ox * p.zx + (vp ? vp.ox : 0), tw);
    const startY = top - mod(p.oy * p.zy + (vp ? vp.oy : 0), th);
    void offX;
    void offY;
    ctx.save();
    ctx.globalAlpha = p.opacity / 255;
    ctx.globalCompositeOperation = BLEND[p.blend] ?? "source-over";
    for (let y = startY; y < top + vh; y += th) {
      for (let x = startX; x < left + vw; x += tw) {
        ctx.drawImage(bm.canvas, 0, 0, bm.w, bm.h, x, y, tw, th);
      }
    }
    ctx.restore();
  }

  private present() {
    const out = this.out[1];
    out.imageSmoothingEnabled = false;
    out.globalAlpha = 1;
    if (this.frozen && this.transitionProgress < 0) {
      out.drawImage(this.frozen, 0, 0);
    } else if (this.frozen && this.transitionProgress >= 0) {
      const p = this.transitionProgress;
      if (this.transitionMask) {
        const a = this.backCtx.getImageData(0, 0, this.width, this.height);
        const fctx = this.frozen.getContext("2d", { willReadFrequently: true }) as Ctx;
        const b = fctx.getImageData(0, 0, this.width, this.height);
        const mask = this.transitionMask;
        const vague = this.transitionVague;
        const level = p * (255 + vague);
        for (let i = 0; i < mask.length; i++) {
          let t = (level - mask[i]) / vague;
          t = t < 0 ? 0 : t > 1 ? 1 : t;
          const k = i * 4;
          b.data[k] += (a.data[k] - b.data[k]) * t;
          b.data[k + 1] += (a.data[k + 1] - b.data[k + 1]) * t;
          b.data[k + 2] += (a.data[k + 2] - b.data[k + 2]) * t;
        }
        out.putImageData(b, 0, 0);
      } else {
        out.drawImage(this.back, 0, 0);
        out.globalAlpha = 1 - p;
        out.drawImage(this.frozen, 0, 0);
        out.globalAlpha = 1;
      }
    } else {
      out.drawImage(this.back, 0, 0);
    }
    if (this.brightness < 255) {
      out.fillStyle = `rgba(0,0,0,${1 - this.brightness / 255})`;
      out.fillRect(0, 0, this.width, this.height);
    }
  }

  get screenSize() {
    return [this.width, this.height];
  }
}

// ---------------------------------------------------------------- helpers
function newCanvasRead(w: number, h: number): [Canvas, Ctx] {
  const c = new OffscreenCanvas(Math.max(1, w), Math.max(1, h));
  const ctx = c.getContext("2d", { willReadFrequently: true })!;
  ctx.imageSmoothingEnabled = false;
  return [c, ctx];
}

const byZ = (a: { z: number; id: number }, b: { z: number; id: number }) => a.z - b.z || a.id - b.id;
const mod = (a: number, n: number) => ((a % n) + n) % n;
const hasTone = (t: number[]) => t[0] !== 0 || t[1] !== 0 || t[2] !== 0 || t[3] !== 0;

function csvColor(csv: string) {
  const [r, g, b, a] = csv.split(",").map(Number);
  return `rgba(${r | 0},${g | 0},${b | 0},${a / 255})`;
}

/** RGSS tone (gray, then add) and color (blend toward a color) on RGBA pixels. */
function applyToneColor(d: Uint8ClampedArray, tone: number[], color: number[], all: boolean) {
  const [tr, tg, tb, gray] = tone;
  const g = gray / 255;
  const ca = color[3] / 255;
  const [cr, cg, cb] = color;
  for (let i = 0; i < d.length; i += 4) {
    if (!all && d[i + 3] === 0) continue;
    let r = d[i],
      gg = d[i + 1],
      b = d[i + 2];
    if (g > 0) {
      const l = 0.299 * r + 0.587 * gg + 0.114 * b;
      r += (l - r) * g;
      gg += (l - gg) * g;
      b += (l - b) * g;
    }
    r += tr;
    gg += tg;
    b += tb;
    if (ca > 0) {
      r += (cr - r) * ca;
      gg += (cg - gg) * ca;
      b += (cb - b) * ca;
    }
    d[i] = r;
    d[i + 1] = gg;
    d[i + 2] = b;
  }
}

/** Ascender, descender and units per em, the way FreeType reads them (from the "hhea" table). */
function fontVerticalMetrics(data: Uint8Array): { asc: number; desc: number; upm: number } | null {
  try {
    const v = new DataView(data.buffer, data.byteOffset, data.byteLength);
    const numTables = v.getUint16(4);
    let upm = 0,
      asc = 0,
      desc = 0;
    for (let i = 0; i < numTables; i++) {
      const rec = 12 + i * 16;
      const tag = String.fromCharCode(data[rec], data[rec + 1], data[rec + 2], data[rec + 3]);
      const off = v.getUint32(rec + 8);
      if (tag === "head") upm = v.getUint16(off + 18);
      if (tag === "hhea") {
        asc = v.getInt16(off + 4);
        desc = v.getInt16(off + 6);
      }
    }
    return upm ? { asc, desc, upm } : null;
  } catch {
    return null;
  }
}

/** Read family names from a TrueType/OpenType font's "name" table. */
function fontNames(data: Uint8Array): string[] {
  try {
    const v = new DataView(data.buffer, data.byteOffset, data.byteLength);
    const numTables = v.getUint16(4);
    for (let i = 0; i < numTables; i++) {
      const rec = 12 + i * 16;
      const tag = String.fromCharCode(data[rec], data[rec + 1], data[rec + 2], data[rec + 3]);
      if (tag !== "name") continue;
      const off = v.getUint32(rec + 8);
      const count = v.getUint16(off + 2);
      const strOff = off + v.getUint16(off + 4);
      const names = new Set<string>();
      for (let j = 0; j < count; j++) {
        const r = off + 6 + j * 12;
        const platform = v.getUint16(r);
        const nameId = v.getUint16(r + 6);
        const len = v.getUint16(r + 8);
        const o = strOff + v.getUint16(r + 10);
        if (nameId !== 1 && nameId !== 4 && nameId !== 16) continue;
        let s = "";
        if (platform === 3 || platform === 0) {
          for (let k = 0; k < len; k += 2) s += String.fromCharCode(v.getUint16(o + k));
        } else {
          for (let k = 0; k < len; k++) s += String.fromCharCode(data[o + k]);
        }
        if (s) names.add(s);
      }
      return [...names];
    }
  } catch {
    /* not a font */
  }
  return [];
}
