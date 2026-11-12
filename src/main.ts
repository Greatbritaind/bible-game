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

// ---------------------------------------------------------------- read aloud
// The game sends the text of each message box (see src/ruby/readaloud.rb); when the student has read
// aloud on, the browser's built-in voice speaks it. The setting is remembered on this computer.
const readAloud = (() => {
  const KEY = "readAloud";
  const VOICE_KEY = "readAloudVoice";
  const SAMPLE = "Shalom! I'm the voice that will read your game.";
  let on = false;
  let chosen: string | null = null; // voiceURI picked by the student
  try {
    chosen = localStorage.getItem(VOICE_KEY);
  } catch {
    /* ignore */
  }
  try {
    on = localStorage.getItem(KEY) === "on";
  } catch {
    /* storage blocked: starts off */
  }
  const supported = typeof speechSynthesis !== "undefined";

  /** English voices on this computer (all voices if it has no English ones). */
  const englishVoices = () => {
    const all = speechSynthesis.getVoices();
    const en = all.filter((v) => v.lang.toLowerCase().startsWith("en"));
    return en.length ? en : all;
  };

  /** The student's chosen voice, or a clear English one: prefer the Chromebook's Google voices. */
  const pickVoice = () => {
    const voices = englishVoices();
    return (
      (chosen ? voices.find((v) => v.voiceURI === chosen) : undefined) ??
      voices.find((v) => /google us english/i.test(v.name)) ??
      voices.find((v) => v.lang.toLowerCase() === "en-us" && /google|natural/i.test(v.name)) ??
      voices.find((v) => v.lang.toLowerCase() === "en-us" && v.localService) ??
      voices.find((v) => v.lang.toLowerCase() === "en-us") ??
      voices[0] ??
      null
    );
  };

  const speak = (text: string, voice = pickVoice()) => {
    if (!supported) return;
    speechSynthesis.cancel(); // a new message replaces the one being read
    const u = new SpeechSynthesisUtterance(text);
    if (voice) u.voice = voice;
    u.lang = voice?.lang ?? "en-US";
    u.rate = 0.95;
    speechSynthesis.speak(u);
  };

  const show = () => {
    const b = $("hud-read");
    b.textContent = on ? "🔊" : "🔈";
    b.title = `Read aloud: ${on ? "on" : "off"}. Right-click or hold to choose a voice.`;
    b.setAttribute("aria-pressed", String(on));
    b.classList.toggle("on", on);
  };

  // ---- voice picker: right-click (two-finger tap) or hold the speaker button
  const pop = $("voice-pop");
  const list = $("voice-list");
  const fillList = () => {
    const current = pickVoice();
    list.replaceChildren();
    const voices = englishVoices();
    if (!voices.length) {
      list.textContent = "This computer has no voices to choose from.";
      return;
    }
    for (const v of voices) {
      const item = document.createElement("button");
      item.setAttribute("role", "radio");
      item.setAttribute("aria-checked", String(v.voiceURI === current?.voiceURI));
      item.textContent = v.name.replace(/^(Microsoft|Google) /, "").replace(/ - English.*$/, "");
      item.title = `${v.name} (${v.lang})`;
      item.onclick = () => {
        chosen = v.voiceURI;
        try {
          localStorage.setItem(VOICE_KEY, chosen);
        } catch {
          /* ignore */
        }
        for (const other of list.children) other.setAttribute("aria-checked", String(other === item));
        speak(SAMPLE, v);
      };
      list.append(item);
    }
  };
  const openPicker = () => {
    fillList();
    pop.hidden = false;
    (list.querySelector('[aria-checked="true"]') as HTMLElement | null)?.focus();
  };
  const closePicker = () => {
    pop.hidden = true;
    speechSynthesis.cancel();
    $("screen").focus();
  };

  return {
    setup() {
      const b = $("hud-read");
      if (!supported) {
        b.hidden = true;
        return;
      }
      show();
      // voices can arrive a moment after the page loads
      speechSynthesis.addEventListener?.("voiceschanged", () => {
        if (!pop.hidden) fillList();
      });
      $("voice-done").onclick = closePicker;
      b.addEventListener("contextmenu", (e) => {
        e.preventDefault();
        openPicker();
      });
      let holdTimer = 0;
      let held = false;
      b.addEventListener("pointerdown", () => {
        held = false;
        holdTimer = window.setTimeout(() => {
          held = true;
          openPicker();
        }, 600);
      });
      for (const ev of ["pointerup", "pointerleave", "pointercancel"]) b.addEventListener(ev, () => clearTimeout(holdTimer));
      b.onclick = () => {
        if (held) {
          held = false; // a long press opened the picker; don't also switch read aloud
          return;
        }
        on = !on;
        try {
          localStorage.setItem(KEY, on ? "on" : "off");
        } catch {
          /* ignore */
        }
        show();
        toast(on ? "Read aloud is on. Right-click the speaker to pick a voice." : "Read aloud is off");
        if (!on) speechSynthesis.cancel();
        $("screen").focus();
      };
    },
    say(text: string) {
      if (on) speak(text);
    },
  };
})();

// ---------------------------------------------------------------- password
// The build writes access.json with a fingerprint (salted SHA-256) of the teacher's password, never the
// password itself. No access.json, or one without a hash, means no password. Spaces, punctuation and
// capital letters don't matter when typing it. A computer that entered the right password remembers it
// until the teacher changes the password.
// This is a simple lock to keep the game to the teacher's students, not real security.
const ACCESS_KEY = "passwordOk";

function normalizePassword(s: string) {
  return s.toLowerCase().replace(/[^\p{L}\p{N}]/gu, "");
}

async function sha256(text: string) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** Resolves once the student may play: right away when there's no password or it was entered before. */
async function passwordGate(): Promise<void> {
  let access: { salt?: string; hash?: string } = {};
  let saved: string | null = null;
  try {
    saved = localStorage.getItem(ACCESS_KEY);
  } catch {
    /* storage blocked: ask every time */
  }
  try {
    const res = await fetch("access.json", { cache: "no-store" });
    if (res.ok) access = await res.json();
    else if (res.status !== 404) throw new Error(String(res.status));
  } catch {
    if (saved) return; // offline: trust a computer that got in before
    access = { hash: "unreachable" };
  }
  if (!access.hash) return; // no password set
  if (saved === access.hash) return;

  const form = $<HTMLFormElement>("password-form");
  const input = $<HTMLInputElement>("password");
  const msg = $("password-msg");
  form.hidden = false;
  input.focus();
  $("password-show").onclick = () => {
    input.type = input.type === "password" ? "text" : "password";
    input.focus();
  };
  await new Promise<void>((resolve) => {
    const check = async () => {
      const typed = normalizePassword(input.value);
      if (!typed) return;
      if (access.hash === "unreachable") {
        msg.textContent = "Couldn't check the password. Check the internet and reload.";
        return;
      }
      if ((await sha256(`${access.salt ?? ""}:${typed}`)) === access.hash) {
        try {
          localStorage.setItem(ACCESS_KEY, access.hash!);
        } catch {
          /* ignore */
        }
        form.hidden = true;
        resolve();
      } else {
        msg.textContent = "That's not it. Ask your teacher for the password.";
        input.select();
      }
    };
    form.onsubmit = (e) => {
      e.preventDefault();
      void check();
    };
    // the Play button also checks the password
    $("play").addEventListener("click", () => void check());
    input.oninput = () => (msg.textContent = "");
  });
}

// ---------------------------------------------------------------- old TV look
// Scanlines and dark edges drawn over the game with CSS (see #crt in style.css). Off by default;
// the choice is remembered on this computer.
function setupCrt() {
  const KEY = "crt";
  let on = false;
  try {
    on = localStorage.getItem(KEY) === "on";
  } catch {
    /* storage blocked: starts off */
  }
  const b = $("hud-crt");
  const show = () => {
    $("crt").hidden = !on;
    document.body.classList.toggle("crt-on", on);
    b.classList.toggle("on", on);
    b.title = on ? "Old TV look: on" : "Old TV look: off";
    b.setAttribute("aria-pressed", String(on));
  };
  show();
  b.onclick = () => {
    on = !on;
    try {
      localStorage.setItem(KEY, on ? "on" : "off");
    } catch {
      /* ignore */
    }
    show();
    toast(on ? "Old TV look is on" : "Old TV look is off");
    $("screen").focus();
  };
}

// ---------------------------------------------------------------- bundles
// The build (scripts/pack.mjs) splits the game into bundles named after a fingerprint of their contents,
// listed in manifest.json. The browser keeps every bundle it downloads, so after an update it only
// downloads the bundles that changed. Bundles download a few at a time; one that gets no data for 3 minutes is retried (school filters can hold a file back while they check it).
const FILE_CACHE = "game-files-v2";
const OLD_CACHES = ["game-files-v1"];

interface BundleInfo {
  name: string;
  file: string;
  /** unpacked size */
  size: number;
  /** download size (differs from size when gzipped) */
  bytes?: number;
  gz?: boolean;
}
interface Manifest {
  bundles: BundleInfo[];
  ruby: BundleInfo;
}

async function loadManifest(): Promise<Manifest | null> {
  for (const name of OLD_CACHES) void caches?.delete(name).catch(() => {});
  if (new URLSearchParams(location.search).has("fresh")) {
    // ?fresh throws away the saved copy (in case it ever gets stuck)
    try {
      await caches.delete(FILE_CACHE);
    } catch {
      /* ignore */
    }
  }
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const ctl = new AbortController();
      const timer = setTimeout(() => ctl.abort(), 10000);
      const res = await fetch("manifest.json", { cache: "no-store", signal: ctl.signal });
      clearTimeout(timer);
      if (res.status === 404) return null; // local test build without bundles
      if (res.ok) return await res.json();
    } catch {
      /* retry */
    }
  }
  throw new Error("Couldn't reach the game's website. Check the internet connection and reload.");
}

/** Promise that rejects after `ms` (so a stuck browser storage call can't freeze the start screen). */
function within<T>(p: Promise<T>, ms: number): Promise<T> {
  let timer = 0;
  return Promise.race([
    p,
    new Promise<never>((_, reject) => (timer = window.setTimeout(() => reject(new Error("timed out")), ms))),
  ]).finally(() => clearTimeout(timer));
}

async function gunzip(data: Uint8Array<ArrayBuffer>): Promise<Uint8Array<ArrayBuffer>> {
  if (data[0] !== 0x1f || data[1] !== 0x8b) return data; // already unpacked (e.g. by a proxy)
  const stream = new Response(data).body!.pipeThrough(new DecompressionStream("gzip"));
  return new Uint8Array(await new Response(stream).arrayBuffer());
}

let cacheWarned = false;
async function warnNoCache(e: unknown) {
  if (cacheWarned) return;
  cacheWarned = true;
  log(`could not keep a copy (${e})`);
  let room = "";
  try {
    const est = await navigator.storage.estimate();
    room = ` (space allowed: ${Math.round((est.quota ?? 0) / 1048576)} MB, used: ${Math.round((est.usage ?? 0) / 1048576)} MB)`;
  } catch {
    /* ignore */
  }
  setStatus(`Note: this browser wouldn't keep a copy of the game, so it will download again next time. ${(e as Error)?.name ?? e}${room}`);
}

/** Gets one bundle (from the saved copy or the web) and returns it unpacked. */
async function fetchBundle(
  info: BundleInfo,
  cache: Cache | null,
  onProgress: (got: number) => void,
  onSource: (s: "saved" | "web") => void,
): Promise<Uint8Array<ArrayBuffer>> {
  const url = new URL(info.file, location.href).href;
  let raw: Uint8Array<ArrayBuffer> | null = null;
  if (cache) {
    try {
      const hit = await within(cache.match(url), 8000);
      if (hit) {
        onSource("saved");
        raw = await readBody(hit, (g) => onProgress(g), 10000);
      }
    } catch (e) {
      log(`${info.name}: saved copy not usable (${e})`);
      raw = null;
      void cache.delete(url).catch(() => {});
    }
  }
  if (!raw) {
    onSource("web");
    for (let attempt = 1; ; attempt++) {
      const ctl = new AbortController();
      try {
        const res = await fetch(url, { signal: ctl.signal });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        raw = await readBody(res, (g) => onProgress(g), 180000);
        break;
      } catch (e) {
        ctl.abort();
        onProgress(0);
        log(`${info.name}: download try ${attempt} failed (${e})`);
        if (attempt >= 6) throw new Error(`Couldn't download part of the game (${info.name}). Check the internet connection and reload.`);
        await new Promise((r) => setTimeout(r, 1000 * attempt));
      }
    }
    if (cache) {
      const data = raw;
      void cache.put(url, new Response(data, { headers: { "content-type": "application/octet-stream" } })).catch(warnNoCache);
    }
  }
  const out = info.gz ? await gunzip(raw) : raw;
  if (out.length !== info.size) {
    void cache?.delete(url).catch(() => {});
    throw new Error(`Part of the game (${info.name}) didn't download correctly. Reload to try again.`);
  }
  return out;
}

/** Runs `jobs` with at most `limit` at a time. */
async function pool(jobs: (() => Promise<void>)[], limit: number) {
  let next = 0;
  await Promise.all(
    Array.from({ length: Math.min(limit, jobs.length) }, async () => {
      while (next < jobs.length) await jobs[next++]();
    }),
  );
}

/** Throws away saved bundles the current game no longer uses. */
async function pruneCache(cache: Cache, keep: Set<string>) {
  try {
    for (const req of await cache.keys()) if (!keep.has(req.url)) await cache.delete(req);
  } catch {
    /* ignore */
  }
}

interface Prepared {
  shared: SharedBuffers;
  game: GameFiles;
  rubyModule: WebAssembly.Module;
  config: Record<string, unknown>;
  title: string;
}

/** Downloads (or loads from the saved copy) everything the game needs. */
async function getGameFiles() {
  let lastProgress = performance.now();
  const watch = window.setInterval(() => {
    const quiet = (performance.now() - lastProgress) / 1000;
    if (quiet > 15) setStatus(`Waiting for the network… nothing new for ${Math.round(quiet)} seconds. School filters sometimes hold a download while they check it; it should continue.`);
  }, 1000);
  try {
    setStatus("Checking for updates…");
    void navigator.storage?.persist?.().catch(() => false);
    const manifest = await loadManifest();
    lastProgress = performance.now();
    if (!manifest) {
      // local test build: one game file, nothing kept
      const progress = { game: [0, 0], ruby: [0, 0] };
      const update = () => {
        lastProgress = performance.now();
        const f = Math.min(1, (progress.game[0] + progress.ruby[0]) / (progress.game[1] + progress.ruby[1] || 1));
        $("bar-fill").style.width = `${Math.round(f * 100)}%`;
        $("play-label").textContent = `Getting ready… ${Math.round(f * 100)}%`;
      };
      const [archive, rubyBytes] = await Promise.all([
        download("game.mkxpz", (g, t) => ((progress.game = [g, t]), update())),
        download("ruby.wasm", (g, t) => ((progress.ruby = [g, t]), update())),
      ]);
      setStatus("Starting up…");
      const shared = createShared(archive.byteLength);
      new Uint8Array(shared.archive).set(archive);
      return [shared, await WebAssembly.compile(rubyBytes)] as const;
    }

    // Place the bundles back to back in one shared buffer
    const parts: [number, number][] = [];
    let offset = 0;
    for (const b of manifest.bundles) {
      parts.push([offset, b.size]);
      offset += b.size;
    }
    const shared = createShared(offset, parts);
    const archive = new Uint8Array(shared.archive);

    const all = [manifest.ruby, ...manifest.bundles];
    const total = all.reduce((n, b) => n + (b.bytes ?? b.size), 0);
    const got = new Map<string, number>();
    let downloading = false;
    const mb = (n: number) => Math.round(n / 1048576);
    const update = () => {
      lastProgress = performance.now();
      const done = [...got.values()].reduce((a, b) => a + b, 0);
      const f = Math.min(1, done / total);
      $("bar-fill").style.width = `${Math.round(f * 100)}%`;
      $("play-label").textContent = `Getting ready… ${Math.round(f * 100)}%`;
      setStatus(`${downloading ? "Downloading" : "Loading from this computer:"} ${mb(done)} of ${mb(total)} MB`);
    };
    let cache: Cache | null = null;
    try {
      cache = typeof caches === "undefined" ? null : await within(caches.open(FILE_CACHE), 8000);
    } catch (e) {
      void warnNoCache(e);
    }

    let rubyBytes: Uint8Array<ArrayBuffer> | null = null;
    const jobs = all.map((info, i) => async () => {
      const data = await fetchBundle(
        info,
        cache,
        (g) => (got.set(info.file, g), update()),
        (src) => (downloading ||= src === "web"),
      );
      if (i === 0) rubyBytes = data;
      else archive.set(data, parts[i - 1][0]);
    });
    await pool(jobs, 4);
    if (cache) void pruneCache(cache, new Set(all.map((b) => new URL(b.file, location.href).href)));
    log(downloading ? "downloaded" : "loaded from saved copy");
    setStatus("Starting up…");
    return [shared, await WebAssembly.compile(rubyBytes!)] as const;
  } finally {
    window.clearInterval(watch);
  }
}

async function prepare(): Promise<Prepared> {
  if (!crossOriginIsolated) {
    // coi-serviceworker reloads the page once to turn this on; if it is still off, the browser can't run the game
    throw new Error("This browser can't run the game here. Try Chrome, and don't use a private or guest window.");
  }
  const [shared, rubyModule] = await getGameFiles();
  const game = new GameFiles(shared.archive, shared.archiveParts);
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
// ---------------------------------------------------------------- leave warning
// While the game is running, closing or reloading the tab asks "Leave site?" so students get a chance to
// save in the game first. Browsers only allow their own plain message here, not a custom one. It isn't
// asked once the game has stopped (closed or crashed).
const leaveGuard = (() => {
  let running = false;
  window.addEventListener("beforeunload", (e) => {
    if (!running) return;
    e.preventDefault();
    e.returnValue = ""; // older Chrome needs this to show the box
  });
  return {
    start: () => (running = true),
    stop: () => (running = false),
  };
})();

function runGame(p: Prepared, existingSaves: [string, Uint8Array][]) {
  leaveGuard.start();
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
    // the game's art uses 2x2 screen pixels per art pixel: one scanline per art pixel row
    document.documentElement.style.setProperty("--crt-rows", String(Math.round(h / 2)));
    document.documentElement.style.setProperty("--crt-cols", String(Math.round(w / 2)));
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
  readAloud.setup();
  setupCrt();

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
      case "speak":
        readAloud.say(m.text);
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
        leaveGuard.stop();
        audio.stop("bgm");
        audio.stop("bgs");
        showError("The game has closed.", "Refresh the page to play again.");
        $("error").querySelector("h2")!.textContent = "Thanks for playing!";
        $("error").querySelector("p")!.hidden = true;
        break;
      case "fatal":
        leaveGuard.stop();
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
  // students can type the password while the game downloads
  let unlocked = false;
  const gate = passwordGate().then(() => {
    unlocked = true;
  });
  const p = await prepare();
  document.title = p.title;
  setupSaveTools(p.title);
  setStatus((await findSave(p.title)) ? "Your save is on this computer." : "");
  $("bar-fill").style.width = "100%";
  const play = $<HTMLButtonElement>("play");
  play.disabled = false;
  $("play-label").textContent = "Play";
  if (!unlocked) {
    // Play (or Enter) checks the password; the game starts as soon as it's right
    $("password").focus();
    await gate;
  } else if (!/[?&]autostart/.test(location.search)) {
    play.focus();
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
