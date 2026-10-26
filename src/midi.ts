// MIDI music, played with SpessaSynth and the game's own SoundFont (soundfont.sf2 from mkxp.json).
import { Sequencer, WorkletSynthesizer } from "spessasynth_lib";
import processorUrl from "spessasynth_lib/dist/spessasynth_processor.min.js?url";
import type { GameFiles } from "./gamefs";

export class MidiPlayer {
  private synth: WorkletSynthesizer | null = null;
  private seq: Sequencer | null = null;
  private ready: Promise<boolean> | null = null;
  private gain: GainNode;
  private token = 0;
  private onEnd: (() => void) | null = null;
  soundFontPath = "soundfont.sf2";

  constructor(
    private ctx: AudioContext,
    out: AudioNode,
    private files: GameFiles,
  ) {
    this.gain = ctx.createGain();
    this.gain.connect(out);
  }

  private init() {
    if (this.ready) return this.ready;
    this.ready = (async () => {
      const fallback = this.files.list("").find((p) => /\.sf[23]$/i.test(p));
      const sf = this.files.get(this.soundFontPath) ?? (fallback ? this.files.get(fallback) : undefined);
      if (!sf) {
        console.warn("No SoundFont found; MIDI music is off.");
        return false;
      }
      await this.ctx.audioWorklet.addModule(processorUrl);
      const synth = new WorkletSynthesizer(this.ctx);
      synth.connect(this.gain);
      await synth.soundBankManager.addSoundBank(sf.slice().buffer, "main");
      await synth.isReady;
      const seq = new Sequencer(synth);
      seq.eventHandler.addEvent("songEnded", "rgss", () => {
        const cb = this.onEnd;
        this.onEnd = null;
        cb?.();
      });
      this.synth = synth;
      this.seq = seq;
      return true;
    })().catch((e) => {
      console.warn("MIDI could not start", e);
      return false;
    });
    return this.ready;
  }

  async play(data: Uint8Array, loop: boolean, volume: number, onEnd: () => void) {
    const token = ++this.token;
    if (!(await this.init()) || token !== this.token) return;
    const seq = this.seq!;
    this.gain.gain.cancelScheduledValues(this.ctx.currentTime);
    this.gain.gain.value = volume * volume;
    this.onEnd = loop ? null : onEnd;
    seq.loopCount = loop ? Infinity : 0;
    seq.loadNewSongList([{ binary: data.slice().buffer, fileName: "music.mid" }]);
    seq.play();
  }

  stop() {
    this.token++;
    this.onEnd = null;
    if (this.seq && !this.seq.paused) this.seq.pause();
    this.synth?.stopAll(true);
  }

  fade(ms: number) {
    const t = this.ctx.currentTime;
    const g = this.gain.gain;
    g.cancelScheduledValues(t);
    g.setValueAtTime(g.value, t);
    g.linearRampToValueAtTime(0, t + ms / 1000);
    const token = ++this.token;
    setTimeout(() => {
      if (token === this.token) this.stop();
    }, ms);
  }

  setVolume(v: number) {
    this.gain.gain.value = v * v;
  }
}
