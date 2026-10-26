// The page: downloads the game, starts the game thread, and handles the screen, keyboard,
// sound, image decoding and save files for it.
import { GameFiles } from "./gamefs";
import { AudioSystem } from "./audio";
import { CTL, DECODE_CAPACITY, KEYS_CAPACITY, TEXT_CAPACITY, createShared, type StartMessage, type ToPage } from "./shared";
import * as saves from "./saves";

const $ = (id: string) => document.getElementById(id)!;
const status = (t: string) => ($("status").textContent = t);
const t0 = performance.now();
const log = (s: string) => console.log(`[player ${((performance.now() - t0) / 1000).toFixed(2)}s] ${s}`);

declare global {
  interface Window {
    __done?: boolean;
    __player?: unknown;
  }
}

function readMkxpConfig(game: GameFiles): Record<string, unknown> {
  const data = game.get("mkxp.json");
  if (!data) return {};
  const text = new TextDecoder()
    .decode(data.slice())
    .replace(/^\s*\/\/.*$/gm, "")
    .replace(/,(\s*[}\]])/g, "$1");
  try {
    return JSON.parse(text);
  } catch {
    return {};
  }
}

function readGameIni(game: GameFiles): Record<string, string> {
  const data = game.get("Game.ini");
  const out: Record<string, string> = {};
  if (!data) return out;
  for (const line of new TextDecoder().decode(data.slice()).split(/\r?\n/)) {
    const m = /^\s*([^=;[]+?)\s*=\s*(.*?)\s*$/.exec(line);
    if (m) out[m[1]] = m[2];
  }
  return out;
}

async function download(url: string, onProgress: (f: number) => void): Promise<ArrayBuffer> {
  const res = await fetch(url);
  if (!res.ok || !res.body) throw new Error(`Could not download ${url}`);
  const total = Number(res.headers.get("content-length")) || 0;
  const reader = res.body.getReader();
  const chunks: Uint8Array[] = [];
  let got = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    chunks.push(value);
    got += value.length;
    if (total) onProgress(got / total);
  }
  const out = new Uint8Array(got);
  let o = 0;
  for (const c of chunks) {
    out.set(c, o);
    o += c.length;
  }
  return out.buffer;
}

export async function startGame() {
  if (!crossOriginIsolated) throw new Error("This page needs cross-origin isolation to run the game.");
  status("Downloading the game…");
  const [archive, rubyModule] = await Promise.all([
    download("game.mkxpz", (f) => status(`Downloading the game… ${Math.round(f * 100)}%`)),
    WebAssembly.compileStreaming(fetch("ruby.wasm")),
  ]);
  log("downloaded");
  const shared = createShared(archive.byteLength);
  new Uint8Array(shared.archive).set(new Uint8Array(archive));
  const game = new GameFiles(shared.archive);
  const config = readMkxpConfig(game);
  const ini = readGameIni(game);
  const title = String(config.windowTitle ?? ini.Title ?? "Game");
  document.title = title;
  const screenW = Number(config.defScreenW) || 640;
  const screenH = Number(config.defScreenH) || 480;

  const ctl = new Int32Array(shared.control);
  const keysBuf = new Uint16Array(shared.keys);
  const textBuf = new Uint16Array(shared.text);
  const decodeBuf = new Uint8ClampedArray(shared.decode);
  const audioPos = new Float64Array(shared.audioPos);
  const audio = new AudioSystem(game);

  // ---- screen
  const canvas = $("screen") as HTMLCanvasElement;
  canvas.width = screenW;
  canvas.height = screenH;
  const screen = canvas.getContext("bitmaprenderer")!;
  const setSize = (w: number, h: number) => {
    if (canvas.width !== w || canvas.height !== h) {
      canvas.width = w;
      canvas.height = h;
      document.documentElement.style.setProperty("--aspect", `${w} / ${h}`);
    }
  };
  setSize(screenW, screenH);
  let pending: ImageBitmap | null = null;
  const tick = () => {
    if (pending) {
      setSize(pending.width, pending.height);
      screen.transferFromImageBitmap(pending);
      pending = null;
    }
    audioPos[0] = audio.position("bgm");
    audioPos[1] = audio.position("bgs");
    Atomics.add(ctl, CTL.FRAME, 1);
    Atomics.notify(ctl, CTL.FRAME);
    requestAnimationFrame(tick);
  };
  requestAnimationFrame(tick);
  document.addEventListener("visibilitychange", () => {
    Atomics.store(ctl, CTL.PAUSED, document.hidden ? 1 : 0);
    Atomics.notify(ctl, CTL.PAUSED);
    if (document.hidden) void audio.ctx.suspend();
    else void audio.ctx.resume();
  });

  // ---- keyboard
  const down = new Set<string>();
  const writeKeys = () => {
    const s = [...down].join(",").slice(0, KEYS_CAPACITY);
    Atomics.add(ctl, CTL.KEYS_SEQ, 1);
    for (let i = 0; i < s.length; i++) keysBuf[i] = s.charCodeAt(i);
    Atomics.store(ctl, CTL.KEYS_LEN, s.length);
    Atomics.add(ctl, CTL.KEYS_SEQ, 1);
  };
  const block = new Set(["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", "Space", "Backspace", "Tab", "F1", "F5", "F6", "F7", "F8", "F9", "F12"]);
  window.addEventListener("keydown", (e) => {
    if ((e.target as HTMLElement)?.closest?.("[data-ui]")) return;
    if (block.has(e.code)) e.preventDefault();
    audio.unlock();
    if (!down.has(e.code)) {
      down.add(e.code);
      writeKeys();
    }
    if (e.key.length === 1 && !e.ctrlKey && !e.metaKey) {
      // Typed characters (for naming the player)
      if (Atomics.load(ctl, CTL.TEXT_READ) === Atomics.load(ctl, CTL.TEXT_LEN)) {
        Atomics.store(ctl, CTL.TEXT_READ, 0);
        Atomics.store(ctl, CTL.TEXT_LEN, 0);
      }
      const n = Atomics.load(ctl, CTL.TEXT_LEN);
      if (n < TEXT_CAPACITY) {
        textBuf[n] = e.key.charCodeAt(0);
        Atomics.store(ctl, CTL.TEXT_LEN, n + 1);
      }
    }
  });
  window.addEventListener("keyup", (e) => {
    if (down.delete(e.code)) writeKeys();
  });
  window.addEventListener("blur", () => {
    down.clear();
    writeKeys();
  });
  canvas.addEventListener("pointermove", (e) => {
    const r = canvas.getBoundingClientRect();
    ctl[CTL.MOUSE_X] = Math.floor(((e.clientX - r.left) / r.width) * canvas.width);
    ctl[CTL.MOUSE_Y] = Math.floor(((e.clientY - r.top) / r.height) * canvas.height);
    ctl[CTL.MOUSE_IN] = 1;
  });
  canvas.addEventListener("pointerleave", () => (ctl[CTL.MOUSE_IN] = 0));
  window.addEventListener("pointerdown", () => audio.unlock());

  // ---- image decoding for the game thread
  const decodeCanvas = new OffscreenCanvas(1, 1);
  const decodeCtx = decodeCanvas.getContext("2d", { willReadFrequently: true })!;
  const answerDecode = (w: number, h: number) => {
    ctl[CTL.DECODE_W] = w;
    ctl[CTL.DECODE_H] = h;
    Atomics.store(ctl, CTL.DECODE_DONE, 1);
    Atomics.notify(ctl, CTL.DECODE_DONE);
  };
  const decode = async (path: string) => {
    try {
      const data = game.get(path);
      if (!data) return answerDecode(0, 0);
      const img = await createImageBitmap(new Blob([data.slice()]), { premultiplyAlpha: "none", colorSpaceConversion: "none" });
      if (img.width * img.height * 4 > DECODE_CAPACITY) {
        console.warn("Image too large:", path);
        return answerDecode(0, 0);
      }
      decodeCanvas.width = img.width;
      decodeCanvas.height = img.height;
      decodeCtx.clearRect(0, 0, img.width, img.height);
      decodeCtx.drawImage(img, 0, 0);
      const px = decodeCtx.getImageData(0, 0, img.width, img.height).data;
      decodeBuf.set(px);
      answerDecode(img.width, img.height);
      img.close();
    } catch (e) {
      console.warn("Could not decode image", path, e);
      answerDecode(0, 0);
    }
  };

  // ---- saves
  const saveKey = title;
  const existing = await saves.load(saveKey);

  // ---- start the game thread
  const worker = new Worker(new URL("./worker.ts", import.meta.url), { type: "module" });
  window.__player = { game, audio, ctl };
  return new Promise<void>((resolve) => {
    worker.onmessage = (ev: MessageEvent<ToPage>) => {
      const m = ev.data;
      switch (m.type) {
        case "frame":
          pending?.close();
          pending = m.image;
          break;
        case "decode":
          void decode(m.path);
          break;
        case "audio":
          if (m.op === "play") void audio.play(m.ch, m.name!, m.vol!, m.pitch!, m.pos!);
          else if (m.op === "stop") audio.stop(m.ch);
          else audio.fade(m.ch, m.ms!);
          break;
        case "msgbox":
          showMessage(m.text).then(() => {
            Atomics.store(ctl, CTL.MSGBOX_DONE, 1);
            Atomics.notify(ctl, CTL.MSGBOX_DONE);
          });
          break;
        case "title":
          document.title = m.title;
          break;
        case "status":
          status(m.text);
          break;
        case "save":
          void saves.store(saveKey, m.path, m.data);
          break;
        case "clipboard":
          navigator.clipboard?.writeText(m.text).catch(() => {});
          break;
        case "log":
          console[m.level]("(game) " + m.text);
          break;
        case "ready":
          log("ruby ready");
          break;
        case "ended":
          status("The game has closed. Refresh the page to play again.");
          window.__done = true;
          resolve();
          break;
        case "fatal":
          console.error("GAME ERROR: " + m.message + "\n" + m.backtrace);
          $("error").hidden = false;
          $("error-text").textContent = m.message + "\n\n" + m.backtrace;
          window.__done = true;
          resolve();
          break;
      }
    };
    worker.onerror = (e) => {
      console.error("Worker error", e.message);
      $("error").hidden = false;
      $("error-text").textContent = e.message;
      window.__done = true;
    };
    const msg: StartMessage = { shared, rubyModule, saves: existing, screen: [screenW, screenH], title, debug: /[?&]debug/.test(location.search) };
    worker.postMessage(msg);
    status("");
  });
}

function showMessage(text: string) {
  return new Promise<void>((resolve) => {
    const box = $("message");
    $("message-text").textContent = text;
    box.hidden = false;
    const ok = $("message-ok") as HTMLButtonElement;
    ok.focus();
    ok.onclick = () => {
      box.hidden = true;
      resolve();
    };
  });
}

startGame().catch((e) => {
  console.error(e);
  status("Something went wrong: " + (e as Error).message);
  window.__done = true;
});
