// Class sessions (multiplayer), the page side. The teacher starts a session on host.html and gets a
// 4-digit code; students type it in ☰ → Class. While joined:
//  - the game thread sends where the player is ("map|x|y|dir|graphic|name|place"); this file shares
//    it and writes the classmates on the same map into shared memory (see ruby/multiplayer.rb);
//  - teacher announcements show on the page; teacher events (gifts, bonus time, rare swarms, Bible
//    questions), emotes and trade steps go to the game through the "class inbox" (JSON lines).
// Classmates are only pictures: nothing about their games changes ours, except a trade both agree to.
//
// Trades are fair: each side's Pokémon goes into an escrow record first, and neither game can read
// the other's Pokémon until both are in (firebase-rules.json enforces this on the server).
import { CTL, MP_CAPACITY, MPI_CAPACITY, type SharedBuffers } from "./shared";

export interface Other { id: string; n: string; x: number; y: number; d: number; s: string; e?: number; es?: number; t?: number }
type Json = Record<string, unknown>;

/** The little database API both servers provide. */
interface DB {
  uid: string;
  get(path: string): Promise<unknown>;
  set(path: string, v: unknown): Promise<void>;
  update(path: string, v: Json): Promise<void>;
  remove(path: string): Promise<void>;
  /** Sets the value only if the current one passes the test (atomic on the server). */
  swapIf(path: string, ok: (cur: unknown) => boolean, v: unknown): Promise<boolean>;
  onValue(path: string, cb: (v: unknown) => void): () => void;
  removeOnDisconnect(path: string): void;
  keepOnDisconnect(path: string): void;
  now(): number;
  stamp(): unknown; // server time when written
  newKey(path: string): string;
}

async function firebaseDB(): Promise<DB> {
  const [{ initializeApp }, auth, db, cfg] = await Promise.all([
    import("firebase/app"),
    import("firebase/auth"),
    import("firebase/database"),
    import("./firebase-config"),
  ]);
  const app = initializeApp(cfg.firebaseConfig);
  const cred = await auth.signInAnonymously(auth.getAuth(app));
  const d = db.getDatabase(app);
  let skew = 0;
  db.onValue(db.ref(d, ".info/serverTimeOffset"), (s) => (skew = Number(s.val()) || 0));
  const r = (p: string) => db.ref(d, p);
  return {
    uid: cred.user.uid,
    get: async (p) => (await db.get(r(p))).val(),
    set: (p, v) => db.set(r(p), v),
    update: (p, v) => db.update(r(p), v),
    remove: (p) => db.remove(r(p)),
    swapIf: async (p, ok, v) => {
      const res = await db.runTransaction(r(p), (cur) => (ok(cur) ? v : undefined));
      return res.committed;
    },
    onValue: (p, cb) => db.onValue(r(p), (s) => cb(s.val())),
    removeOnDisconnect: (p) => void db.onDisconnect(r(p)).remove(),
    keepOnDisconnect: (p) => void db.onDisconnect(r(p)).cancel(),
    now: () => Date.now() + skew,
    stamp: () => db.serverTimestamp(),
    newKey: (p) => db.push(r(p)).key!,
  };
}

/** Test-only database: tabs of one browser share a copy through a BroadcastChannel (?debug&mptest). */
function localDB(): DB {
  const uid = "u" + Math.random().toString(36).slice(2, 9);
  const ch = new BroadcastChannel("rtj-mp-db");
  let root: Json = {};
  const subs = new Set<{ path: string; cb: (v: unknown) => void; last: string }>();
  const parts = (p: string) => p.split("/").filter(Boolean);
  const read = (p: string) => parts(p).reduce<unknown>((o, k) => (o && typeof o === "object" ? (o as Json)[k] : undefined), root);
  const write = (p: string, v: unknown) => {
    const ks = parts(p);
    let o = root;
    for (const k of ks.slice(0, -1)) o = (o[k] && typeof o[k] === "object" ? o[k] : (o[k] = {})) as Json;
    if (v === null || v === undefined) delete o[ks[ks.length - 1]];
    else o[ks[ks.length - 1]] = JSON.parse(JSON.stringify(v));
  };
  const fire = () => {
    for (const s of subs) {
      const v = read(s.path) ?? null;
      const j = JSON.stringify(v);
      if (j !== s.last) { s.last = j; s.cb(v); }
    }
  };
  const apply = (p: string, v: unknown, local: boolean) => {
    write(p, v);
    if (local) ch.postMessage({ p, v });
    fire();
  };
  ch.onmessage = (e) => {
    const m = e.data;
    if (m.hello) ch.postMessage({ snapshot: root });
    else if (m.snapshot) { if (!Object.keys(root).length) { root = m.snapshot; fire(); } }
    else apply(m.p, m.v, false);
  };
  ch.postMessage({ hello: true });
  (window as unknown as { __mpdb: unknown }).__mpdb = { set: (p: string, v: unknown) => apply(p, v, true), read };
  window.addEventListener("beforeunload", () => {
    for (const p of gone) ch.postMessage({ p, v: null });
  });
  const gone = new Set<string>();
  return {
    uid,
    get: async (p) => read(p) ?? null,
    set: async (p, v) => apply(p, v, true),
    update: async (p, v) => { for (const [k, x] of Object.entries(v)) apply(p + "/" + k, x, true); },
    remove: async (p) => apply(p, null, true),
    swapIf: async (p, ok, v) => { if (!ok(read(p) ?? null)) return false; apply(p, v, true); return true; },
    onValue: (p, cb) => { const s = { path: p, cb, last: "\u0000" }; subs.add(s); queueMicrotask(fire); return () => subs.delete(s); },
    removeOnDisconnect: (p) => gone.add(p),
    keepOnDisconnect: (p) => gone.delete(p),
    now: () => Date.now(),
    stamp: () => Date.now(),
    newKey: () => "t" + Date.now().toString(36) + Math.random().toString(36).slice(2, 6),
  };
}

const STALE_MS = 2 * 60 * 1000; // ignore anyone who hasn't been heard from in 2 minutes
export interface Announcement { text: string; save: boolean }

export class ClassPlay {
  private ctl: Int32Array;
  private buf: Uint16Array;
  private ibuf: Uint16Array;
  private db: DB | null = null;
  private connecting: Promise<DB> | null = null;
  private code = "";
  private map = -1;
  private last: Omit<Other, "id"> | null = null;
  private pendingMove = 0;
  private count = 0;
  private stops: (() => void)[] = [];
  private stopMap: (() => void) | null = null;
  private stopInbox: (() => void) | null = null;
  private beat = 0;
  private joinedAt = 0;
  private emoteSeq = 0;
  // class inbox for the game: messages stay until the game says it handled them
  private inbox: { id: number; line: string }[] = [];
  private nextMsg = 1;
  private pushedEvents = new Set<string>();
  private seenAnnounce = "";
  private tradeWatch = new Map<string, () => void>();
  onChange: () => void = () => {};
  onEnded: () => void = () => {};
  onAnnounce: (a: Announcement) => void = () => {};

  constructor(shared: SharedBuffers, private test: boolean) {
    this.ctl = new Int32Array(shared.control);
    this.buf = new Uint16Array(shared.mp);
    this.ibuf = new Uint16Array(shared.mpi);
  }

  get joined() { return !!this.code; }
  get classCode() { return this.code; }
  get here() { return this.count; }

  private connect(): Promise<DB> {
    if (this.db) return Promise.resolve(this.db);
    this.connecting ??= (this.test ? Promise.resolve(localDB()) : firebaseDB()).then((d) => {
      this.db = d;
      this.watchInbox();
      return d;
    });
    this.connecting.catch(() => (this.connecting = null));
    return this.connecting;
  }

  async join(code: string): Promise<"ok" | "nocode" | "error"> {
    code = code.replace(/\D/g, "");
    if (code.length !== 4) return "nocode";
    let db: DB;
    try {
      db = await this.connect();
    } catch (e) {
      console.warn("class: could not connect", e);
      return "error";
    }
    if (this.test && code === "0000") return "nocode";
    try {
      const exp = Number(this.test ? db.now() + 3600000 : await db.get(`sessions/${code}/expires`));
      if (!(exp > db.now())) return "nocode";
    } catch (e) {
      console.warn("class: join failed", e);
      return "error";
    }
    this.code = code;
    this.map = -1;
    this.last = null;
    this.joinedAt = db.now();
    const s = `sessions/${code}`;
    db.removeOnDisconnect(`${s}/who/${db.uid}`);
    this.stops.push(
      db.onValue(`${s}/expires`, (v) => {
        if (this.test) return;
        const exp = Number(v);
        if (!v || !(exp > db.now())) { this.leave(); this.onEnded(); }
      }),
      db.onValue(`${s}/announce`, (v) => this.announce(v as Json | null)),
      db.onValue(`${s}/events`, (v) => this.events((v ?? {}) as Record<string, Json>)),
    );
    this.beat = window.setInterval(() => {
      if (this.map >= 0) void db.update(`${s}/maps/${this.map}/${db.uid}`, { t: db.stamp() }).catch(() => {});
    }, 30000);
    Atomics.store(this.ctl, CTL.MP_ON, 1);
    try { localStorage.setItem("classCode", JSON.stringify({ code, at: Date.now() })); } catch { /* private window */ }
    this.onChange();
    return "ok";
  }

  leave() {
    const db = this.db;
    clearInterval(this.beat);
    this.stops.forEach((f) => f());
    this.stops = [];
    this.stopMap?.();
    this.stopMap = null;
    if (db && this.code) {
      const s = `sessions/${this.code}`;
      if (this.map >= 0) { db.keepOnDisconnect(`${s}/maps/${this.map}/${db.uid}`); void db.remove(`${s}/maps/${this.map}/${db.uid}`).catch(() => {}); }
      db.keepOnDisconnect(`${s}/who/${db.uid}`);
      void db.remove(`${s}/who/${db.uid}`).catch(() => {});
    }
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

  // ---------------------------------------------------------------- where everyone is
  /** From the game thread: "map|x|y|dir|graphic|name|place" */
  gameState(state: string) {
    const db = this.db;
    if (!this.code || !db) return;
    const [m, x, y, d, s, n, place] = state.split("|");
    const map = Number(m);
    const me = { n: n ?? "", x: Number(x), y: Number(y), d: Number(d), s: s ?? "" };
    const base = `sessions/${this.code}`;
    if (map !== this.map) {
      if (this.map >= 0) { db.keepOnDisconnect(`${base}/maps/${this.map}/${db.uid}`); void db.remove(`${base}/maps/${this.map}/${db.uid}`).catch(() => {}); }
      this.map = map;
      const path = `${base}/maps/${map}/${db.uid}`;
      db.removeOnDisconnect(path);
      void db.set(path, { ...me, t: db.stamp() }).catch((e) => console.warn("class: could not share position", e));
      void db.set(`${base}/who/${db.uid}`, { n: me.n, p: place ?? "", t: db.stamp() }).catch(() => {});
      this.stopMap?.();
      this.stopMap = db.onValue(`${base}/maps/${map}`, (v) => {
        const all = (v ?? {}) as Record<string, Omit<Other, "id">>;
        const now = db.now();
        this.write(Object.entries(all)
          .filter(([id, o]) => id !== db.uid && o && typeof o.x === "number" && (!o.t || now - o.t < STALE_MS))
          .map(([id, o]) => ({ id, ...o })));
      });
      this.last = me;
      return;
    }
    this.last = me;
    if (!this.pendingMove) {
      this.pendingMove = window.setTimeout(() => {
        this.pendingMove = 0;
        if (this.last && this.code && this.map >= 0) {
          const l = this.last;
          void db.update(`sessions/${this.code}/maps/${this.map}/${db.uid}`, { x: l.x, y: l.y, d: l.d, s: l.s }).catch(() => {});
        }
      }, 120);
    }
  }

  /** Classmates on this map, one per line: uid|name|x|y|dir|emoteSeq|emote|graphic */
  private write(others: Other[]) {
    const clean = (v: unknown) => String(v ?? "").replace(/[|\n\r]/g, " ");
    const text = others.slice(0, 40)
      .map((o) => [o.id, clean(o.n).slice(0, 16), o.x | 0, o.y | 0, o.d | 0, (o.es ?? 0) | 0, (o.e ?? 0) | 0, clean(o.s).slice(0, 64)].join("|"))
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

  // ---------------------------------------------------------------- emotes
  emote(e: number) {
    const db = this.db;
    if (!db || !this.code || this.map < 0) return;
    this.emoteSeq++;
    void db.update(`sessions/${this.code}/maps/${this.map}/${db.uid}`, { e, es: this.emoteSeq }).catch(() => {});
    this.send({ k: "emote", e });
  }

  // ---------------------------------------------------------------- the class inbox
  private send(msg: Json) {
    this.inbox.push({ id: this.nextMsg, line: JSON.stringify({ id: this.nextMsg, ...msg }) });
    this.nextMsg++;
    this.flushInbox();
  }

  private flushInbox() {
    let text = this.inbox.map((m) => m.line).join("\n");
    if (text.length > MPI_CAPACITY) text = text.slice(0, MPI_CAPACITY);
    for (let i = 0; i < text.length; i++) this.ibuf[i] = text.charCodeAt(i);
    Atomics.store(this.ctl, CTL.MPI_LEN, text.length);
    Atomics.add(this.ctl, CTL.MPI_SEQ, 1);
  }

  // ---------------------------------------------------------------- teacher announcements and events
  private announce(a: Json | null) {
    if (!a || !this.db) return;
    const id = String(a.id ?? "");
    if (!id || id === this.seenAnnounce) return;
    this.seenAnnounce = id;
    if (Number(a.t) < this.joinedAt - 60000) return; // old news from before you joined
    this.onAnnounce({ text: String(a.text ?? "").slice(0, 300), save: !!a.save });
    if (a.save) Atomics.store(this.ctl, CTL.SAVE_NOW, 1);
  }

  private events(all: Record<string, Json>) {
    const db = this.db;
    if (!db) return;
    for (const [id, ev] of Object.entries(all)) {
      if (this.pushedEvents.has(id) || !ev) continue;
      this.pushedEvents.add(id);
      const rem = Number(ev.t) + Number(ev.dur ?? 0) - db.now();
      const k = String(ev.k);
      if (k !== "gift" && !(rem > 0)) continue; // timed events that already ended
      this.send({ ...ev, k, ev: id, rem: Math.max(0, rem | 0) });
    }
  }

  // ---------------------------------------------------------------- messages from the game
  async gameCommand(json: string) {
    let m: Json;
    try { m = JSON.parse(json); } catch { return; }
    const k = String(m.k);
    if (k === "ack") {
      const upto = Number(m.id);
      this.inbox = this.inbox.filter((x) => x.id > upto);
      this.flushInbox();
      return;
    }
    let db: DB;
    try { db = await this.connect(); } catch { if (k.startsWith("trade")) this.send({ k: "trade_error", ref: m.ref, tid: m.tid }); return; }
    try {
      switch (k) {
        case "answer":
          if (this.code) await db.set(`sessions/${this.code}/answers/${m.ev}/${db.uid}`, { n: String(m.n ?? "").slice(0, 20), ok: !!m.ok, t: db.stamp() });
          break;
        case "trade_ask": await this.tradeAsk(db, m); break;
        case "trade_offer": await this.tradeOffer(db, m); break;
        case "trade_confirm": await this.tradeConfirm(db, m); break;
        case "trade_decline": await this.tradeStop(db, String(m.tid), "decline"); break;
        case "trade_cancel": await this.tradeStop(db, String(m.tid), "cancel"); break;
        case "trade_check":
          // start the watcher fresh so the game hears the current state again
          this.tradeWatch.get(String(m.tid))?.();
          this.tradeWatch.delete(String(m.tid));
          this.watchTrade(db, String(m.tid), String(m.role));
          break;
        case "trade_done":
          await db.set(`trades/${m.tid}/${m.role === "a" ? "da" : "db"}`, true);
          this.tradeWatch.get(String(m.tid))?.();
          this.tradeWatch.delete(String(m.tid));
          break;
      }
    } catch (e) {
      console.warn("class:", k, e);
      if (k.startsWith("trade")) this.send({ k: "trade_error", ref: m.ref, tid: m.tid });
    }
  }

  // ---------------------------------------------------------------- trades
  // trades/<tid>/meta {a, b, an, bn, st, t}: st goes ask → offered → swap, or to decline/cancel
  // trades/<tid>/oa, ob: what each side offers (shown to the other)   pa, pb: the Pokémon (escrow)
  private async tradeAsk(db: DB, m: Json) {
    if (!this.code) throw new Error("not in a class");
    const tid = db.newKey("trades");
    await db.set(`trades/${tid}`, {
      meta: { a: db.uid, b: String(m.to), an: String(m.me ?? "").slice(0, 20), bn: String(m.toName ?? "").slice(0, 20), st: "ask", t: db.stamp() },
      oa: m.offer ?? {},
    });
    await db.set(`inbox/${m.to}/${tid}`, db.stamp());
    this.send({ k: "trade_started", ref: m.ref, tid });
    this.watchTrade(db, tid, "a");
  }

  private async tradeOffer(db: DB, m: Json) {
    const tid = String(m.tid);
    await db.set(`trades/${tid}/pb`, String(m.pkmn));
    await db.set(`trades/${tid}/ob`, m.offer ?? {});
    const ok = await db.swapIf(`trades/${tid}/meta/st`, (cur) => cur === "ask", "offered");
    if (!ok) this.watchTrade(db, tid, "b"); // the asker gave up: the watcher hands the Pokémon back
    else this.watchTrade(db, tid, "b");
  }

  private async tradeConfirm(db: DB, m: Json) {
    const tid = String(m.tid);
    await db.set(`trades/${tid}/pa`, String(m.pkmn));
    await db.swapIf(`trades/${tid}/meta/st`, (cur) => cur === "offered", "swap");
  }

  private async tradeStop(db: DB, tid: string, st: "decline" | "cancel") {
    await db.swapIf(`trades/${tid}/meta/st`, (cur) => cur === "ask" || cur === "offered", st);
  }

  /** Follows one trade and tells the game every step, including the other Pokémon once both are in. */
  private watchTrade(db: DB, tid: string, role: string) {
    if (this.tradeWatch.has(tid)) return;
    let lastSt = "";
    const stop = db.onValue(`trades/${tid}/meta/st`, async (v) => {
      const st = v == null ? "gone" : String(v);
      if (st === lastSt) return;
      lastSt = st;
      try {
        if (st === "offered" && role === "a") {
          this.send({ k: "trade_state", tid, st, offer: await db.get(`trades/${tid}/ob`) });
        } else if (st === "swap") {
          const pkmn = await db.get(`trades/${tid}/${role === "a" ? "pb" : "pa"}`);
          this.send({ k: "trade_state", tid, st, pkmn: String(pkmn ?? "") });
        } else {
          this.send({ k: "trade_state", tid, st });
        }
      } catch (e) {
        console.warn("class: trade", e);
        this.send({ k: "trade_error", tid });
      }
    });
    this.tradeWatch.set(tid, stop);
  }

  /** Trade requests from classmates */
  private watchInbox() {
    const db = this.db!;
    this.stopInbox?.();
    this.stopInbox = db.onValue(`inbox/${db.uid}`, async (v) => {
      for (const tid of Object.keys((v ?? {}) as Json)) {
        void db.remove(`inbox/${db.uid}/${tid}`).catch(() => {});
        try {
          const meta = (await db.get(`trades/${tid}/meta`)) as Json | null;
          if (!meta || meta.st !== "ask" || meta.b !== db.uid) continue;
          const offer = await db.get(`trades/${tid}/oa`);
          this.send({ k: "trade_ask", tid, from: String(meta.an ?? "A classmate"), fromUid: String(meta.a ?? ""), offer });
          this.watchTrade(db, tid, "b");
        } catch (e) {
          console.warn("class: trade request", e);
        }
      }
    });
  }
}
