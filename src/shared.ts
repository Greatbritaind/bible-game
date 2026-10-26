// Shared memory between the page (main thread) and the game thread (worker).
// The game thread blocks with Atomics.wait instead of returning to the browser, so Ruby code can
// run normally from top to bottom (RPG Maker games expect Graphics.update to just "wait a frame").

export const CTL = {
  FRAME: 0, // page increments once per display refresh
  DECODE_DONE: 1, // page sets to 1 when an image request is answered
  DECODE_W: 2,
  DECODE_H: 3,
  MSGBOX_DONE: 4, // page sets to 1 when a message box is closed
  KEYS_SEQ: 5, // even = stable, odd = being written
  KEYS_LEN: 6,
  TEXT_LEN: 7, // characters typed so far (written by page)
  TEXT_READ: 8, // characters consumed (written by game thread)
  MOUSE_X: 9,
  MOUSE_Y: 10,
  MOUSE_IN: 11,
  PAUSED: 12, // page sets to 1 while the tab is hidden
  SIZE: 16,
} as const;

export const KEYS_CAPACITY = 512; // UTF-16 code units for the comma-separated list of held keys
export const TEXT_CAPACITY = 1024;
export const DECODE_CAPACITY = 48 * 1024 * 1024; // largest image the game can load (RGBA bytes)
export const SCREEN_MAX_PIXELS = 1024 * 768; // largest game screen; two frame buffers of this size

export interface SharedBuffers {
  control: SharedArrayBuffer;
  keys: SharedArrayBuffer;
  text: SharedArrayBuffer;
  decode: SharedArrayBuffer;
  audioPos: SharedArrayBuffer; // Float64 [bgm, bgs]
  archive: SharedArrayBuffer;
  screen: SharedArrayBuffer; // two RGBA frame buffers, filled by the game thread
}

export function createShared(archiveBytes: number): SharedBuffers {
  return {
    control: new SharedArrayBuffer(CTL.SIZE * 4),
    keys: new SharedArrayBuffer(KEYS_CAPACITY * 2),
    text: new SharedArrayBuffer(TEXT_CAPACITY * 2),
    decode: new SharedArrayBuffer(DECODE_CAPACITY),
    audioPos: new SharedArrayBuffer(16),
    archive: new SharedArrayBuffer(archiveBytes),
    screen: new SharedArrayBuffer(SCREEN_MAX_PIXELS * 4 * 2),
  };
}

/** Messages the game thread sends to the page. */
export type ToPage =
  | { type: "frame"; buffer: number; width: number; height: number }
  | { type: "decode"; path: string }
  | { type: "msgbox"; text: string }
  | { type: "audio"; op: "play" | "stop" | "fade"; ch: string; name?: string; vol?: number; pitch?: number; pos?: number; ms?: number }
  | { type: "title"; title: string }
  | { type: "status"; text: string }
  | { type: "save"; path: string; data: Uint8Array | null }
  | { type: "ready" }
  | { type: "ended" }
  | { type: "fatal"; message: string; backtrace: string }
  | { type: "clipboard"; text: string }
  | { type: "log"; level: "log" | "warn" | "error"; text: string };

/** Message the page sends to start the game thread. */
export interface StartMessage {
  shared: SharedBuffers;
  rubyModule: WebAssembly.Module;
  saves: [string, Uint8Array][];
  screen: [number, number];
  title: string;
  debug: boolean;
  /** Test-only: Ruby code to run once the player is on a map (from ?cmd= with ?debug). */
  debugCommand?: string;
}
