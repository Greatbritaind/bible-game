// MIDI music. Placeholder for now: MIDI tracks are silent until a synthesizer is added.
import type { GameFiles } from "./gamefs";

export class MidiPlayer {
  constructor(
    _ctx: AudioContext,
    _out: AudioNode,
    _files: GameFiles,
  ) {}

  play(_data: Uint8Array, _loop: boolean, _volume: number, _onEnd: () => void) {}
  stop() {}
  fade(_ms: number) {}
  setVolume(_v: number) {}
}
