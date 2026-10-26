// The page: start screen, downloads, and everything the game thread can't do itself
// (showing frames, keyboard and touch, sound, decoding images, keeping save files).
import "@fontsource/atkinson-hyperlegible/400.css";
import "@fontsource/atkinson-hyperlegible/700.css";
import "./style.css";
import { GameFiles } from "./gamefs";
import { AudioSystem } from "./audio";
import { CTL, DECODE_CAPACITY, KEYS_CAPACITY, SCREEN_MAX_PIXELS, TEXT_CAPACITY, createShared, type SharedBuffers, type StartMessage, type ToPage } from "./shared";
import * as saves from "./saves";

const SAVE_FILE = "Game.rxdata";

const $ = <T extends HTMLElement = HTMLElement>(id: string) => document.getElementById(id) as T;
const setStatus = (t: string) => ($("status").textContent = t);
const t0 = performance.now();
const log = (s: string) => console.log(`[player ${((performance.now() - t0) / 1000).toFixed(2)}s] ${s}`);

declare global {
  interface Window {
    __done?: boolean;
    __player?: unknown;
  }
}

let toastTimer = 0;
function toast(message: string) {
  const box = $("toast");
  box.textContent = message;
  box.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = window.setTimeout(() => (box.hidden = true), 4000);
}

function showError(message: string, details = "") {
  $("error").hidden = false;
  $("error-text").textContent = details ? `${message}\n\n${details}` : message;
  window.__done = true;
}

// ---------------------------------------------------------------- game settings
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

// ---------------------------------------------------------------- downloads
/** Reads a response body with progress. Gives up if no data arrives for `stallMs`. */
async function readBody(
  res: Response,
  onProgress: (got: number, total: number) => void,
  stallMs = 0,
): Promise<Uint8Array<ArrayBuffer>> {
  if (!res.body) throw new Error("empty response");
  const total = Number(res.headers.get("content-length")) || 0;
  const reader = res.body.getReader();
  const chunks: Uint8Array[] = [];
  let got = 0;
  for (;;) {
    let timer = 0;
    const next = reader.read();
    const { done, value } = stallMs
      ? await Promise.race([
          next,
          new Promise<never>((_, reject) => (timer = window.setTimeout(() => reject(new Error("stalled")), stallMs))),
        ]).finally(() => clearTimeout(timer))
      : await next;
    if (done) break;
    chunks.push(value);
    got += value.length;
    onProgress(got, total);
  }
  const out = new Uint8Array(got);
  let o = 0;
  for (const c of chunks) {
    out.set(c, o);
    o += c.length;
  }
  return out;
}

async function download(url: string, onProgress: (got: number, total: number) => void): Promise<Uint8Array<ArrayBuffer>> {
  const res = await fetch(url);
  if (!res.ok || !res.body) throw new Error(`Could not download ${url} (${res.status})`);
  return readBody(res, onProgress);
}

// Keeps a copy of the big files in the browser so each visit doesn't download ~120 MB again.
// versions.json (written by the build) changes only when a file's contents change.
const FILE_CACHE = "game-files-v1";
/** Where each big file is coming from right now, for the status line. */
const fileSource: Record<string, "saved" | "web"> = {};

async function fileVersions(): Promise<Record<string, string>> {
  if (new URLSearchParams(location.search).has("fresh")) {
    // ?fresh throws away the saved copy (in case it ever gets stuck)
    try {
      await caches.delete(FILE_CACHE);
    } catch {
      /* ignore */
    }
    return {};
  }
  try {
    const ctl = new AbortController();
    const timer = setTimeout(() => ctl.abort(), 8000);
    const res = await fetch("versions.json", { cache: "no-store", signal: ctl.signal });
    clearTimeout(timer);
    return res.ok ? await res.json() : {};
  } catch {
    return {};
  }
}

/** Promise that rejects after `ms` (so a stuck browser storage call can't freeze the start screen). */
function within<T>(p: Promise<T>, ms: number): Promise<T> {
  let timer = 0;
  return Promise.race([
    p,
    new Promise<never>((_, reject) => (timer = window.setTimeout(() => reject(new Error("timed out")), ms))),
  ]).finally(() => clearTimeout(timer));
}

async function cachedDownload(
  name: string,
  version: string | undefined,
  onProgress: (got: number, total: number) => void,
): Promise<Uint8Array<ArrayBuffer>> {
  if (!version || typeof caches === "undefined") return download(name, onProgress);
  const key = new URL(`${name}?v=${version}`, location.href).href;
  let cache: Cache | null = null;
  try {
    cache = await within(caches.open(FILE_CACHE), 8000);
    const hit = await within(cache.match(key), 8000);
    if (hit) {
      fileSource[name] = "saved";
      const bytes = await readBody(hit, onProgress, 10000);
      log(`${name}: using saved copy`);
      return bytes;
    }
  } catch (e) {
    // the saved copy is unreadable: throw it away and download instead
    log(`${name}: saved copy not usable (${e}), downloading`);
    fileSource[name] = "web";
    cache = null;
    void caches.delete(FILE_CACHE).catch(() => {});
  }
  fileSource[name] = "web";
  const bytes = await download(key, onProgress);
  if (cache) {
    const c = cache;
    // save in the background; the game doesn't wait for it
    void (async () => {
      try {
        for (const req of await c.keys()) if (new URL(req.url).pathname.endsWith(`/${name}`)) await c.delete(req);
        await c.put(key, new Response(bytes, { headers: { "content-type": "application/octet-stream", "content-length": String(bytes.length) } }));
        log(`${name}: saved a copy`);
      } catch (e) {
        log(`${name}: could not keep a copy (${e})`);
      }
    })();
  }
  return bytes;
}

interface Prepared {
  shared: SharedBuffers;
  game: GameFiles;
  rubyModule: WebAssembly.Module;
  config: Record<string, unknown>;
  title: string;
}

async function prepare(): Promise<Prepared> {
  if (!crossOriginIsolated) {
    // coi-serviceworker reloads the page once to turn this on; if it is still off, the browser can't run the game
    throw new Error("This browser can't run the game here. Try Chrome, and don't use a private or guest window.");
  }
  const progress = { game: [0, 0], ruby: [0, 0] };
  const update = () => {
    const got = progress.game[0] + progress.ruby[0];
    const total = progress.game[1] + progress.ruby[1];
    const f = total ? Math.min(1, got / total) : 0;
    $("bar-fill").style.width = `${Math.round(f * 100)}%`;
    $("play-label").textContent = `Getting ready… ${Math.round(f * 100)}%`;
    const mb = (n: number) => Math.round(n / 1048576);
    const web = Object.values(fileSource).includes("web");
    lastProgress = performance.now();
    if (total) setStatus(`${web ? "Downloading" : "Loading from this computer:"} ${mb(got)} of ${mb(total)} MB`);
  };
  let lastProgress = performance.now();
  const watch = window.setInterval(() => {
    const quiet = (performance.now() - lastProgress) / 1000;
    if (quiet > 15) setStatus(`Waiting for the network… nothing new for ${Math.round(quiet)} seconds.`);
  }, 1000);
  setStatus("Checking for updates…");
  const versions = await fileVersions();
  lastProgress = performance.now();
  let files: [Uint8Array<ArrayBuffer>, Uint8Array<ArrayBuffer>];
  try {
    files = await Promise.all([
      cachedDownload("game.mkxpz", versions["game.mkxpz"], (g, t) => ((progress.game = [g, t]), update())),
      cachedDownload("ruby.wasm", versions["ruby.wasm"], (g, t) => ((progress.ruby = [g, t]), update())),
    ]);
  } finally {
    window.clearInterval(watch);
  }
  const [archive, rubyBytes] = files;
  log("downloaded");
  setStatus("Starting up…");
  const rubyModule = await WebAssembly.compile(rubyBytes);
  const shared = createShared(archive.byteLength);
  new Uint8Array(shared.archive).set(archive);
  const game = new GameFiles(shared.archive);
  const config = readMkxpConfig(game);
  const ini = readGameIni(game);
  const title = String(config.windowTitle ?? ini.Title ?? "Game");
  return { shared, game, rubyModule, config, title };
}

// ---------------------------------------------------------------- save files on the start screen
function setupSaveTools(title: string) {
  $("save-tools").hidden = false;
  const input = $<HTMLInputElement>("save-file");
  let pending: Uint8Array | null = null;

  const write = async (data: Uint8Array) => {
    await saves.store(SAVE_KEY, SAVE_FILE, data);
    toast("Save loaded ✔ Press Play, then Continue.");
    setStatus("Your save is on this computer.");
  };

  $("load-save").onclick = () => input.click();
  $("download-save-start").onclick = () => void downloadSave(title);
  input.onchange = async () => {
    const file = input.files?.[0];
    input.value = "";
    if (!file) return;
    const data = new Uint8Array(await file.arrayBuffer());
    // Ruby save data starts with the bytes 04 08
    if (!file.name.toLowerCase().endsWith(".rxdata") || data.length < 16 || data[0] !== 4 || data[1] !== 8) {
      toast("That file is not a save from this game.");
      return;
    }
    if (await findSave(title)) {
      pending = data;
      $("confirm").hidden = false;
      $("confirm-no").focus();
    } else await write(data);
  };
  $("confirm-yes").onclick = async () => {
    $("confirm").hidden = true;
    if (pending) await write(pending);
    pending = null;
  };
  $("confirm-no").onclick = () => {
    $("confirm").hidden = true;
    pending = null;
  };
}

/** Saves stay under the game's original name so renaming the game never loses anyone's progress. */
const SAVE_KEY = "Bible Game";

async function findSave(_title: string) {
  return (await saves.load(SAVE_KEY)).find(([n]) => n.toLowerCase() === SAVE_FILE.toLowerCase())?.[1] ?? null;
}

async function downloadSave(title: string) {
  const data = await findSave(title);
  if (!data) {
    toast("No save yet. Save in the game menu first.");
    return;
  }
  const a = document.createElement("a");
  a.href = URL.createObjectURL(new Blob([data.slice()]));
  a.download = title.replace(/[^A-Za-z0-9]+/g, "") + "-save.rxdata";
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(a.href), 10000);
  toast("Save downloaded ✔");
}

// ---------------------------------------------------------------- running the game
function runGame(p: Prepared, existingSaves: [string, Uint8Array][]) {
  const { shared, game, rubyModule, config, title } = p;
  const screenW = Number(config.defScreenW) || 640;
  const screenH = Number(config.defScreenH) || 480;
  const ctl = new Int32Array(shared.control);
  const keysBuf = new Uint16Array(shared.keys);
  const textBuf = new Uint16Array(shared.text);
  const decodeBuf = new Uint8ClampedArray(shared.decode);
  const audioPos = new Float64Array(shared.audioPos);
  const audio = new AudioSystem(game);
  if (typeof config.midiSoundFont === "string") audio.midi.soundFontPath = config.midiSoundFont;
  audio.unlock();

  // ---- screen
  const canvas = $<HTMLCanvasElement>("screen");
  const screen = canvas.getContext("2d")!;
  const screenBuf = new Uint8ClampedArray(shared.screen);
  let frameImage: ImageData | null = null;
  const setSize = (w: number, h: number) => {
    if (canvas.width === w && canvas.height === h && frameImage) return;
    canvas.width = w;
    canvas.height = h;
    frameImage = new ImageData(w, h);
    document.documentElement.style.setProperty("--aspect-w", String(w));
    document.documentElement.style.setProperty("--aspect-h", String(h));
  };
  setSize(screenW, screenH);
  canvas.focus();
  let pending: { buffer: number; width: number; height: number } | null = null;
  const tick = () => {
    if (pending) {
      const { buffer, width, height } = pending;
      setSize(width, height);
      const start = buffer * SCREEN_MAX_PIXELS * 4;
      frameImage!.data.set(screenBuf.subarray(start, start + width * height * 4));
      screen.putImageData(frameImage!, 0, 0);
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

  // ---- keyboard and touch
  const down = new Set<string>();
  const writeKeys = () => {
    const s = [...down].join(",").slice(0, KEYS_CAPACITY);
    Atomics.add(ctl, CTL.KEYS_SEQ, 1);
    for (let i = 0; i < s.length; i++) keysBuf[i] = s.charCodeAt(i);
    Atomics.store(ctl, CTL.KEYS_LEN, s.length);
    Atomics.add(ctl, CTL.KEYS_SEQ, 1);
  };
  const press = (code: string, isDown: boolean) => {
    if (isDown === down.has(code)) return;
    if (isDown) down.add(code);
    else down.delete(code);
    writeKeys();
  };
  const block = new Set(["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", "Space", "Backspace", "Tab", "F1", "F5", "F6", "F7", "F8", "F9", "F12"]);
  window.addEventListener("keydown", (e) => {
    if ((e.target as HTMLElement)?.closest?.("[data-ui], input")) return;
    if (block.has(e.code)) e.preventDefault();
    // Enter/Space on a focused page button would click it; send those keys to the game instead
    if ((e.target as HTMLElement)?.closest?.("button")) {
      e.preventDefault();
      canvas.focus();
    }
    audio.unlock();
    press(e.code, true);
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
  window.addEventListener("keyup", (e) => press(e.code, false));
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

  if (matchMedia("(pointer: coarse)").matches) {
    const pad = $("touchpad");
    pad.hidden = false;
    for (const b of pad.querySelectorAll<HTMLButtonElement>("button[data-key]")) {
      const code = b.dataset.key!;
      b.addEventListener("pointerdown", (e) => {
        e.preventDefault();
        b.setPointerCapture(e.pointerId);
        press(code, true);
      });
      const up = (e: PointerEvent) => {
        e.preventDefault();
        press(code, false);
      };
      b.addEventListener("pointerup", up);
      b.addEventListener("pointercancel", up);
      b.addEventListener("contextmenu", (e) => e.preventDefault());
    }
  }

  // ---- buttons while playing
  $("hud").hidden = false;
  const hudClick = (id: string, action: () => void) =>
    ($(id).onclick = () => {
      canvas.focus();
      action();
    });
  hudClick("hud-keys", () => ($("keys-pop").hidden = !$("keys-pop").hidden));
  hudClick("hud-save", () => void downloadSave(title));
  hudClick("hud-full", () => {
    if (document.fullscreenElement) void document.exitFullscreen();
    else void document.documentElement.requestFullscreen().catch(() => {});
  });
  $("keys-pop").onclick = () => ($("keys-pop").hidden = true);

  // ---- image decoding for the game thread (native decoders live on the page)
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
      decodeBuf.set(decodeCtx.getImageData(0, 0, img.width, img.height).data);
      answerDecode(img.width, img.height);
      img.close();
    } catch (e) {
      console.warn("Could not decode image", path, e);
      answerDecode(0, 0);
    }
  };

  // ---- start the game thread
  const worker = new Worker(new URL("./worker.ts", import.meta.url), { type: "module" });
  window.__player = { game, audio, ctl, press };
  worker.onmessage = (ev: MessageEvent<ToPage>) => {
    const m = ev.data;
    switch (m.type) {
      case "frame":
        pending = m;
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
        void showMessage(m.text).then(() => {
          Atomics.store(ctl, CTL.MSGBOX_DONE, 1);
          Atomics.notify(ctl, CTL.MSGBOX_DONE);
          canvas.focus();
        });
        break;
      case "title":
        document.title = m.title;
        break;
      case "status":
        log(m.text);
        break;
      case "save":
        void saves.store(SAVE_KEY, m.path, m.data);
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
        audio.stop("bgm");
        audio.stop("bgs");
        showError("The game has closed.", "Refresh the page to play again.");
        $("error").querySelector("h2")!.textContent = "Thanks for playing!";
        $("error").querySelector("p")!.hidden = true;
        break;
      case "fatal":
        console.error("GAME ERROR: " + m.message + "\n" + m.backtrace);
        showError(m.message, m.backtrace);
        break;
    }
  };
  worker.onerror = (e) => showError("The game thread stopped.", e.message);
  const msg: StartMessage = {
    shared,
    rubyModule,
    saves: existingSaves,
    screen: [screenW, screenH],
    title,
    debug: /[?&]debug/.test(location.search),
    debugCommand: /[?&]debug/.test(location.search) ? (new URLSearchParams(location.search).get("cmd") ?? undefined) : undefined,
  };
  worker.postMessage(msg);
}

function showMessage(text: string) {
  return new Promise<void>((resolve) => {
    $("message").hidden = false;
    $("message-text").textContent = text;
    const ok = $<HTMLButtonElement>("message-ok");
    ok.focus();
    ok.onclick = () => {
      $("message").hidden = true;
      resolve();
    };
  });
}

// ---------------------------------------------------------------- start screen
async function main() {
  const p = await prepare();
  document.title = p.title;
  setupSaveTools(p.title);
  setStatus((await findSave(p.title)) ? "Your save is on this computer." : "");
  $("bar-fill").style.width = "100%";
  const play = $<HTMLButtonElement>("play");
  play.disabled = false;
  $("play-label").textContent = "Play";
  play.focus();
  if (!/[?&]autostart/.test(location.search)) {
    await new Promise<void>((resolve) => play.addEventListener("click", () => resolve(), { once: true }));
  }
  $("start").hidden = true;
  runGame(p, await saves.load(SAVE_KEY));
}

main().catch((e) => {
  console.error(e);
  $("play-label").textContent = "Can't start";
  setStatus((e as Error).message);
  window.__done = true;
});
