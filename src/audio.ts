// Sound for the RGSS runtime: BGM, BGS and ME channels plus overlapping sound effects.
import type { GameFiles } from "./gamefs";
import { MidiPlayer } from "./midi";

const EXTENSIONS = [".ogg", ".wav", ".mp3", ".mid", ".midi", ".m4a"];

interface Channel {
  key: string;
  source: AudioBufferSourceNode | null;
  gain: GainNode | null;
  startedAt: number;
  offset: number;
  rate: number;
  midi: boolean;
}

export class AudioSystem {
  readonly ctx: AudioContext;
  private master: GainNode;
  private buffers = new Map<string, Promise<AudioBuffer | null>>();
  private channels: Record<string, Channel> = {};
  private seSources = new Set<AudioBufferSourceNode>();
  private bgmPausedForMe: { name: string; vol: number; pitch: number; pos: number } | null = null;
  private lastBgm: { name: string; vol: number; pitch: number } | null = null;
  readonly midi: MidiPlayer;

  constructor(private files: GameFiles) {
    this.ctx = new AudioContext();
    this.master = this.ctx.createGain();
    this.master.connect(this.ctx.destination);
    this.midi = new MidiPlayer(this.ctx, this.master, files);
    for (const ch of ["bgm", "bgs", "me"]) {
      this.channels[ch] = { key: "", source: null, gain: null, startedAt: 0, offset: 0, rate: 1, midi: false };
    }
  }

  unlock() {
    if (this.ctx.state !== "running") void this.ctx.resume();
  }

  setVolume(v: number) {
    this.master.gain.value = v;
  }

  private load(name: string) {
    const found = this.files.resolve(name, EXTENSIONS);
    if (!found) return { found: null, buffer: Promise.resolve(null) };
    const key = found.path.toLowerCase();
    if (/\.midi?$/.test(key)) return { found, buffer: Promise.resolve(null) };
    let p = this.buffers.get(key);
    if (!p) {
      p = this.ctx.decodeAudioData(found.data.slice().buffer).catch((e) => {
        console.warn("Could not decode audio", found.path, e);
        return null;
      });
      this.buffers.set(key, p);
    }
    return { found, buffer: p };
  }

  async play(ch: string, name: string, vol: number, pitch: number, pos: number) {
    if (!name) {
      if (ch !== "se") this.stop(ch);
      return;
    }
    const volume = Math.max(0, Math.min(100, vol)) / 100;
    const rate = Math.max(0.1, pitch / 100);
    if (ch === "se") {
      const { buffer } = this.load(name);
      const buf = await buffer;
      if (!buf) return;
      const src = this.ctx.createBufferSource();
      src.buffer = buf;
      src.playbackRate.value = rate;
      const g = this.ctx.createGain();
      g.gain.value = volume * volume;
      src.connect(g).connect(this.master);
      src.onended = () => this.seSources.delete(src);
      this.seSources.add(src);
      src.start();
      return;
    }
    const c = this.channels[ch];
    const { found, buffer } = this.load(name);
    const key = found ? found.path.toLowerCase() : "";
    if (ch === "bgm") this.lastBgm = { name, vol, pitch };
    // Same track already playing: just change the volume (RGSS behavior)
    if (c.key === key && (c.source || c.midi) && ch !== "me") {
      if (c.gain) c.gain.gain.value = volume * volume;
      if (c.midi) this.midi.setVolume(volume);
      return;
    }
    this.stop(ch);
    if (!found) return;
    c.key = key;
    if (ch === "me" && this.channels.bgm.key) {
      // Music effects pause the background music, which resumes afterwards
      this.bgmPausedForMe = { ...this.lastBgm!, pos: this.position("bgm") };
      this.stop("bgm");
    }
    if (/\.midi?$/.test(key)) {
      c.midi = true;
      this.midi.play(found.data, ch !== "me", volume, () => {
        if (ch === "me") this.afterMe();
      });
      return;
    }
    const buf = await buffer;
    if (!buf || c.key !== key) return;
    const src = this.ctx.createBufferSource();
    src.buffer = buf;
    src.playbackRate.value = rate;
    if (ch !== "me") {
      src.loop = true;
      const loop = loopPoints(found.data, buf.sampleRate);
      if (loop) {
        src.loopStart = loop[0];
        src.loopEnd = loop[1] > loop[0] ? loop[1] : buf.duration;
      }
    }
    const g = this.ctx.createGain();
    g.gain.value = volume * volume;
    src.connect(g).connect(this.master);
    const offset = Math.max(0, pos || 0) % Math.max(buf.duration, 0.001);
    src.start(0, offset);
    c.source = src;
    c.gain = g;
    c.startedAt = this.ctx.currentTime;
    c.offset = offset;
    c.rate = rate;
    if (ch === "me") src.onended = () => {
      if (c.source === src) {
        c.source = null;
        c.key = "";
        this.afterMe();
      }
    };
  }

  private afterMe() {
    const b = this.bgmPausedForMe;
    this.bgmPausedForMe = null;
    if (b && !this.channels.bgm.key) void this.play("bgm", b.name, b.vol, b.pitch, b.pos);
  }

  stop(ch: string) {
    if (ch === "se") {
      for (const s of this.seSources) {
        try {
          s.stop();
        } catch {
          /* already stopped */
        }
      }
      this.seSources.clear();
      return;
    }
    const c = this.channels[ch];
    if (!c) return;
    if (c.midi) this.midi.stop();
    if (c.source) {
      c.source.onended = null;
      try {
        c.source.stop();
      } catch {
        /* already stopped */
      }
    }
    c.source = null;
    c.gain = null;
    c.key = "";
    c.midi = false;
    if (ch === "bgm") this.bgmPausedForMe = null;
  }

  fade(ch: string, ms: number) {
    const c = this.channels[ch];
    if (!c) return;
    if (c.midi) {
      this.midi.fade(ms);
      c.midi = false;
      c.key = "";
      return;
    }
    if (!c.source || !c.gain) return;
    const t = this.ctx.currentTime;
    c.gain.gain.setValueAtTime(c.gain.gain.value, t);
    c.gain.gain.linearRampToValueAtTime(0, t + ms / 1000);
    const src = c.source;
    src.stop(t + ms / 1000);
    c.source = null;
    c.gain = null;
    c.key = "";
  }

  position(ch: string) {
    const c = this.channels[ch];
    if (!c?.source?.buffer) return 0;
    const played = c.offset + (this.ctx.currentTime - c.startedAt) * c.rate;
    const src = c.source;
    if (src.loop && played > src.buffer!.duration) {
      const ls = src.loopStart,
        le = src.loopEnd || src.buffer!.duration;
      return ls + ((played - ls) % Math.max(le - ls, 0.001));
    }
    return played;
  }
}

/** LOOPSTART / LOOPLENGTH tags (in samples) used by many RPG Maker music files. */
function loopPoints(data: Uint8Array, rate: number): [number, number] | null {
  const head = new TextDecoder("latin1").decode(data.slice(0, Math.min(data.length, 16384)));
  const s = /LOOPSTART=(\d+)/i.exec(head);
  if (!s) return null;
  const start = +s[1] / rate;
  const l = /LOOPLENGTH=(\d+)/i.exec(head);
  return [start, l ? start + +l[1] / rate : 0];
}
