// The game thread: runs Ruby (the game's scripts) and draws each frame.
import { ConsoleStdout, Directory, File, OpenFile, PreopenDirectory, WASI } from "@bjorn3/browser_wasi_shim";
import { RubyVM } from "@ruby/wasm-wasi";
import { CIMap, GameFiles } from "./gamefs";
import { Engine } from "./engine";
import type { StartMessage, ToPage } from "./shared";
import rgssSource from "./ruby/rgss.rb?raw";
import bootSource from "./ruby/boot.rb?raw";

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
  const game = new GameFiles(start.shared.archive);
  const engine = new Engine(game, start.shared, post);
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
  const api = engine.api();
  const frame = api.frame;
  (self as unknown as { RGSS: unknown }).RGSS = {
    ...api,
    frame: (sync: string) => {
      frame(sync);
      if (++frames % 30 === 0) syncSaves();
    },
    loading: (i: number, n: number) => {
      if (i % 20 === 0 || i === n) post({ type: "status", text: `Loading game code ${Math.round((i / n) * 100)}%` });
    },
    next_frame: () => engine.waitFrame(),
    game_ended: () => {
      syncSaves();
      post({ type: "ended" });
    },
    fatal: (message: string, backtrace: string) => {
      syncSaves();
      post({ type: "fatal", message, backtrace });
    },
  };

  const { vm } = await RubyVM.instantiateModule({ module: start.rubyModule, wasip1: wasi });
  post({ type: "ready" });
  vm.eval(`$__game_title = ${JSON.stringify(start.title)}; $__debug = ${start.debug}`);
  const [w, h] = start.screen;
  // Synchronous: the game runs until it quits. Graphics.update sleeps between frames.
  vm.eval(rgssSource + `\nGraphics.resize_screen(${w}, ${h})\n` + bootSource);
}
