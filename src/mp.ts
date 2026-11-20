// Class sessions (multiplayer), the page side. The teacher starts a session on host.html and gets a
// 4-digit code; students type it in ☰ → Class. While joined, the game thread sends where the player
// is ("map|x|y|dir|graphic|name|place") and this file shares it with the server, then writes the
// classmates on the same map into shared memory for the game to draw (see ruby/multiplayer.rb).
// Classmates are only pictures: no events, battles or saves are shared, and there is no chat.
import { CTL, MP_CAPACITY, type SharedBuffers } from "./shared";

export interface Other { id: string; n: string; x: number; y: number; d: number; s: string; t?: number }

/** The server. Firebase in real use; ?debug&mptest uses a BroadcastChannel between tabs for testing. */
export interface Transport {
  uid(): string;
  /** "ok", "nocode" (no such class or it ended) or "error" (couldn't reach the server) */
  join(code: string): Promise<"ok" | "nocode" | "error">;
  setMap(map: number, me: Omit<Other, "id">, place: string): void;
  move(map: number, me: Omit<Other, "id">): void;
  watchMap(map: number, cb: (others: Other[]) => void): void;
  onEnded(cb: () => void): void;
  leave(): void;
}

const STALE_MS = 2 * 60 * 1000; // ignore anyone who hasn't been heard from in 2 minutes

async function firebaseTransport(): Promise<Transport> {
  const [{ initializeApp }, auth, db, cfg] = await Promise.all([
    import("firebase/app"),
    import("firebase/auth"),
    import("firebase/database"),
    import("./firebase-config"),
  ]);
  const app = initializeApp(cfg.firebaseConfig);
  const a = auth.getAuth(app);
  const cred = await auth.signInAnonymously(a);
  const uid = cred.user.uid;
  const d = db.getDatabase(app);
  let code = "";
  let mapRef: ReturnType<typeof db.ref> | null = null;
  let stopMap: (() => void) | null = null;
  let stopEnd: (() => void) | null = null;
  let whoRef: ReturnType<typeof db.ref> | null = null;
  let beat = 0;
  let skew = 0;
  db.onValue(db.ref(d, ".info/serverTimeOffset"), (s) => (skew = Number(s.val()) || 0));
  return {
    uid: () => uid,
    async join(c) {
      try {
        const s = await db.get(db.ref(d, `sessions/${c}/expires`));
        const exp = Number(s.val());
        if (!s.exists() || !(exp > Date.now() + skew)) return "nocode";
        code = c;
        whoRef = db.ref(d, `sessions/${code}/who/${uid}`);
        void db.onDisconnect(whoRef).remove();
        beat = window.setInterval(() => {
          if (mapRef) void db.update(mapRef, { t: db.serverTimestamp() }).catch(() => {});
        }, 30000);
        return "ok";
      } catch (e) {
        console.warn("class join failed", e);
        return "error";
      }
    },
    setMap(map, me, place) {
      if (!code) return;
      if (mapRef) {
        void db.onDisconnect(mapRef).cancel();
        void db.remove(mapRef).catch(() => {});
      }
      mapRef = db.ref(d, `sessions/${code}/maps/${map}/${uid}`);
      void db.onDisconnect(mapRef).remove();
      void db.set(mapRef, { ...me, t: db.serverTimestamp() }).catch((e) => console.warn("class: could not share position", e));
      if (whoRef) void db.set(whoRef, { n: me.n, p: place, t: db.serverTimestamp() }).catch(() => {});
    },
    move(_map, me) {
      if (mapRef) void db.update(mapRef, { x: me.x, y: me.y, d: me.d, s: me.s }).catch(() => {});
    },
    watchMap(map, cb) {
      stopMap?.();
      stopMap = db.onValue(db.ref(d, `sessions/${code}/maps/${map}`), (snap) => {
        const v = (snap.val() ?? {}) as Record<string, Omit<Other, "id">>;
        const now = Date.now() + skew;
        cb(Object.entries(v)
          .filter(([id, o]) => id !== uid && o && typeof o.x === "number" && (!o.t || now - o.t < STALE_MS))
          .map(([id, o]) => ({ id, ...o })));
      });
    },
    onEnded(cb) {
      stopEnd?.();
      let timer = 0;
      stopEnd = db.onValue(db.ref(d, `sessions/${code}/expires`), (s) => {
        clearTimeout(timer);
        const exp = Number(s.val());
        if (!s.exists() || !(exp > Date.now() + skew)) cb();
        else timer = window.setTimeout(cb, Math.min(exp - (Date.now() + skew), 2 ** 31 - 1));
      });
    },
    leave() {
      clearInterval(beat);
      stopMap?.(); stopMap = null;
      stopEnd?.(); stopEnd = null;
      if (mapRef) { void db.onDisconnect(mapRef).cancel(); void db.remove(mapRef).catch(() => {}); }
      if (whoRef) { void db.onDisconnect(whoRef).cancel(); void db.remove(whoRef).catch(() => {}); }
      mapRef = whoRef = null;
      code = "";
    },
  };
}

/** Test transport: tabs of the same browser share positions through a BroadcastChannel. */
function localTransport(): Transport {
  const id = Math.random().toString(36).slice(2, 10);
  const ch = new BroadcastChannel("rtj-mp-test");
  const all = new Map<string, Other & { m: number }>();
  let map = -1;
  let me: (Other & { m: number }) | null = null;
  let cb: ((o: Other[]) => void) | null = null;
  const emit = () => cb?.([...all.values()].filter((o) => o.m === map && o.id !== id));
  ch.onmessage = (e) => {
    const o = e.data as (Other & { m: number }) | { bye: string } | { hello: true };
    if ("bye" in o) all.delete(o.bye);
    else if ("hello" in o) { if (me) ch.postMessage(me); return; }
    else all.set(o.id, o);
    emit();
  };
  return {
    uid: () => id,
    async join(c) { return c === "0000" ? "nocode" : "ok"; },
    setMap(m, o) { map = m; me = { id, m, ...o }; ch.postMessage(me); ch.postMessage({ hello: true }); emit(); },
    move(m, o) { me = { id, m, ...o }; ch.postMessage(me); },
    watchMap(m, f) { map = m; cb = f; emit(); },
    onEnded() {},
    leave() { ch.postMessage({ bye: id }); cb = null; map = -1; },
  };
}

export class ClassPlay {
  private ctl: Int32Array;
  private buf: Uint16Array;
  private transport: Transport | null = null;
  private code = "";
  private map = -1;
  private last: Omit<Other, "id"> | null = null;
  private pendingMove = 0;
  private count = 0;
  onChange: () => void = () => {};
  onEnded: () => void = () => {};

  constructor(shared: SharedBuffers, private test: boolean) {
    this.ctl = new Int32Array(shared.control);
    this.buf = new Uint16Array(shared.mp);
  }

  get joined() { return !!this.code; }
  get classCode() { return this.code; }
  get here() { return this.count; }

  async join(code: string): Promise<"ok" | "nocode" | "error"> {
    code = code.replace(/\D/g, "");
    if (code.length !== 4) return "nocode";
    try {
      this.transport ??= this.test ? localTransport() : await firebaseTransport();
    } catch (e) {
      console.warn("class: could not connect", e);
      return "error";
    }
    const r = await this.transport.join(code);
    if (r !== "ok") return r;
    this.code = code;
    this.map = -1;
    this.last = null;
    this.transport.onEnded(() => { this.leave(); this.onEnded(); });
    Atomics.store(this.ctl, CTL.MP_ON, 1);
    try { localStorage.setItem("classCode", JSON.stringify({ code, at: Date.now() })); } catch { /* private window */ }
    this.onChange();
    return "ok";
  }

  leave() {
    this.transport?.leave();
    this.code = "";
    this.map = -1;
    this.count = 0;
    Atomics.store(this.ctl, CTL.MP_ON, 0);
    this.write([]);
    try { localStorage.removeItem("classCode"); } catch { /* private window */ }
    this.onChange();
  }

  /** The code from last time, if the player joined a class in the last 3 hours (reloads rejoin). */
  savedCode(): string {
    try {
      const v = JSON.parse(localStorage.getItem("classCode") ?? "null");
      if (v && Date.now() - v.at < 3 * 60 * 60 * 1000) return String(v.code);
    } catch { /* ignore */ }
    return "";
  }

  /** From the game thread: "map|x|y|dir|graphic|name|place" */
  gameState(state: string) {
    if (!this.code || !this.transport) return;
    const [m, x, y, d, s, n, place] = state.split("|");
    const map = Number(m);
    const me = { n: n ?? "", x: Number(x), y: Number(y), d: Number(d), s: s ?? "" };
    if (map !== this.map) {
      this.map = map;
      this.transport.setMap(map, me, place ?? "");
      this.transport.watchMap(map, (others) => this.write(others));
      this.last = me;
      return;
    }
    this.last = me;
    // walking sends a few updates a second at most
    if (!this.pendingMove) {
      this.pendingMove = window.setTimeout(() => {
        this.pendingMove = 0;
        if (this.last && this.code) this.transport!.move(this.map, this.last);
      }, 120);
    }
  }

  private write(others: Other[]) {
    const clean = (v: unknown) => String(v ?? "").replace(/[|\n\r]/g, " ");
    const text = others.slice(0, 40)
      .map((o) => [o.id, clean(o.n).slice(0, 16), o.x | 0, o.y | 0, o.d | 0, clean(o.s).slice(0, 64)].join("|"))
      .join("\n");
    const n = Math.min(text.length, MP_CAPACITY);
    for (let i = 0; i < n; i++) this.buf[i] = text.charCodeAt(i);
    Atomics.store(this.ctl, CTL.MP_LEN, n);
    Atomics.add(this.ctl, CTL.MP_SEQ, 1);
    if (others.length !== this.count) {
      this.count = others.length;
      this.onChange();
    }
  }
}
