// The game thread: runs Ruby (the game's scripts) and draws each frame.
import { ConsoleStdout, Directory, File, OpenFile, PreopenDirectory, WASI } from "@bjorn3/browser_wasi_shim";
import { RubyVM } from "@ruby/wasm-wasi";
import { CIMap, GameFiles } from "./gamefs";
import { Engine } from "./engine";
import { CTL, MP_CAPACITY, MPI_CAPACITY, type StartMessage, type ToPage } from "./shared";
import rgssSource from "./ruby/rgss.rb?raw";
import bootSource from "./ruby/boot.rb?raw";
import iteratorsSource from "./ruby/iterators.rb?raw";
import readAloudSource from "./ruby/readaloud.rb?raw";
import tradeSource from "./ruby/trade.rb?raw";
import autoSaveSource from "./ruby/autosave.rb?raw";
import guideSource from "./ruby/guide.rb?raw";
import mpSource from "./ruby/multiplayer.rb?raw";

const post = (msg: ToPage, transfer: Transferable[] = []) => (self as unknown as Worker).postMessage(msg, transfer);

// Forward the game thread's console output to the page's console
for (const level of ["log", "warn", "error"] as const) {
  const original = console[level].bind(console);
  console[level] = (...args: unknown[]) => {
    original(...args);
    post({ type: "log", level, text: args.map(String).join(" ") });
  };
}

self.onmessage = async (ev: MessageEvent<StartMessage>) => {
  try {
    await run(ev.data);
  } catch (e) {
    post({ type: "fatal", message: String((e as Error)?.message ?? e), backtrace: String((e as Error)?.stack ?? "") });
  }
};

async function run(start: StartMessage) {
  (self as unknown as { __debug: boolean }).__debug = start.debug;
  const game = new GameFiles(start.shared.archive, start.shared.archiveParts);
  const engine = new Engine(game, start.shared, post);
  const control = new Int32Array(start.shared.control);
  const mpBuf = new Uint16Array(start.shared.mp);
  const mpiBuf = new Uint16Array(start.shared.mpi);
  let mpSeen = -1;
  let mpiSeen = -1;
  const readText = (buf: Uint16Array, n: number) => {
    let s = "";
    for (let i = 0; i < n; i += 4096) s += String.fromCharCode(...buf.subarray(i, Math.min(n, i + 4096)));
    return s;
  };
  await engine.loadFonts();

  // Save files live in /save; any change is sent to the page, which keeps them in the browser
  const saveDir = new Directory(new CIMap());
  for (const [name, data] of start.saves) {
    const f = new File(new ArrayBuffer(0));
    f.data = data;
    saveDir.contents.set(name, f);
  }
  const savedState = new Map<string, Uint8Array>();
  for (const [name, f] of saveDir.contents) if (f instanceof File) savedState.set(name, f.data);
  const syncSaves = () => {
    for (const [name, f] of saveDir.contents) {
      if (!(f instanceof File)) continue;
      if (savedState.get(name) !== f.data) {
        savedState.set(name, f.data);
        post({ type: "save", path: name, data: f.data.slice() });
      }
    }
    for (const name of [...savedState.keys()]) {
      if (!saveDir.contents.has(name)) {
        savedState.delete(name);
        post({ type: "save", path: name, data: null });
      }
    }
  };

  const rootMap = new CIMap();
  rootMap.set("game", game.root);
  rootMap.set("save", saveDir);
  const wasi = new WASI(
    [],
    ["RUBY_THREAD_VM_STACK_SIZE=16777216"],
    [
      new OpenFile(new File([])),
      ConsoleStdout.lineBuffered((l) => console.log("[ruby] " + l)),
      ConsoleStdout.lineBuffered((l) => console.warn("[ruby] " + l)),
      new PreopenDirectory("/", rootMap),
    ],
    { debug: false },
  );

  let frames = 0;
  const api = engine.api() as Record<string, (...a: never[]) => unknown>;
  if (start.debug) {
    // Count calls per API function (debug only)
    const counts = new Map<string, number>();
    for (const [k, f] of Object.entries(api)) {
      api[k] = (...a: never[]) => {
        void k;
        counts.set(k, (counts.get(k) ?? 0) + 1);
        return (f as (...x: unknown[]) => unknown)(...(a as unknown[]));
      };
    }
    let n = 0;
    let syncBytes = 0;
    const origFrame = api.frame;
    api.frame = ((...a: never[]) => {
      syncBytes += String(a[0] ?? "").length;
      if (++n % 120 === 0) {
        console.log(`[sync] ${Math.round(syncBytes / 120)} chars/frame`);
        syncBytes = 0;
        console.log("[calls] " + [...counts].sort((x, y) => y[1] - x[1]).slice(0, 8).map(([k, v]) => `${k}=${v}`).join(" "));
        counts.clear();
      }
      return (origFrame as (...x: unknown[]) => unknown)(...(a as unknown[]));
    }) as never;
  }
  const frame = api.frame as (sync: string) => void;
  (self as unknown as { RGSS: unknown }).RGSS = {
    ...api,
    frame: (sync: string) => {
      frame(sync);
      if (++frames % 30 === 0) syncSaves();
    },
    ruby_memory: () => (self as unknown as { __rubyMemory?: () => number }).__rubyMemory?.() ?? 0,
    loading: (i: number, n: number) => {
      if (i % 20 === 0 || i === n) post({ type: "status", text: `Loading game code ${Math.round((i / n) * 100)}%` });
    },
    next_frame: () => engine.waitFrame(),
    speak: (text: string) => post({ type: "speak", text: String(text) }),
    progress: () => post({ type: "progress" }),
    sync_saves: () => syncSaves(),
    autosaved: () => post({ type: "autosaved" }),
    guide: (json: string) => post({ type: "guide", json }),
    save_now_requested: () => Atomics.exchange(control, CTL.SAVE_NOW, 0),
    // Multiplayer (class sessions): the game sends where the player is; the page sends back the
    // classmates on the same map. Nothing happens unless the player joined a class.
    mp_active: () => Atomics.load(control, CTL.MP_ON),
    mp_send: (state: string) => post({ type: "mp", state: String(state) }),
    mp_read: () => {
      const seq = Atomics.load(control, CTL.MP_SEQ);
      if (seq === mpSeen) return "~"; // nothing new
      mpSeen = seq;
      return readText(mpBuf, Math.min(Atomics.load(control, CTL.MP_LEN), MP_CAPACITY));
    },
    // Class inbox: teacher events, trade steps, emotes (JSON lines). "~" when nothing changed.
    mp_inbox: () => {
      const seq = Atomics.load(control, CTL.MPI_SEQ);
      if (seq === mpiSeen) return "~";
      mpiSeen = seq;
      return readText(mpiBuf, Math.min(Atomics.load(control, CTL.MPI_LEN), MPI_CAPACITY));
    },
    mp_cmd: (json: string) => post({ type: "mpcmd", json: String(json) }),
    trade_available: () => (start.tradeServer ? 1 : 0),
    // Trading post requests. The game waits for the answer (a worker may make synchronous requests).
    trade: (action: string, body: string) => {
      try {
        const xhr = new XMLHttpRequest();
        xhr.open("POST", start.tradeServer.replace(/\/+$/, "") + "/" + action, false);
        xhr.setRequestHeader("Content-Type", "text/plain");
        xhr.send(body);
        return xhr.status === 200 ? xhr.responseText : "";
      } catch {
        return "";
      }
    },
    game_ended: () => {
      syncSaves();
      post({ type: "ended" });
    },
    fatal: (message: string, backtrace: string) => {
      syncSaves();
      post({ type: "fatal", message, backtrace });
    },
  };

  const { vm, instance } = await RubyVM.instantiateModule({ module: start.rubyModule, wasip1: wasi });
  (self as unknown as { __rubyMemory: () => number }).__rubyMemory = () =>
    (instance.exports.memory as WebAssembly.Memory).buffer.byteLength;
  post({ type: "ready" });
  vm.eval(`$__game_title = ${JSON.stringify(start.title)}; $__debug = ${start.debug}; $__debug_gc = ${start.debugCommand === "gc"}; $__debug_cmd = ${JSON.stringify(start.debugCommand ?? "").replace(/#/g, "\\#")}`);
  const [w, h] = start.screen;
  // Synchronous: the game runs until it quits. Graphics.update sleeps between frames.
  vm.eval(iteratorsSource);
  vm.eval(rgssSource + `\nGraphics.resize_screen(${w}, ${h})\n` + readAloudSource + "\n" + tradeSource + "\n" + autoSaveSource + "\n" + guideSource + "\n" + mpSource + "\n" + bootSource);
}
