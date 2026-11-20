// The teacher's page for class sessions: start a session to get a 4-digit code, watch who joined,
// and end it. Students join from the game (☰ → 👥 Join class).
import "@fontsource/atkinson-hyperlegible/400.css";
import "@fontsource/atkinson-hyperlegible/700.css";
import "./host.css";
import { initializeApp } from "firebase/app";
import { getAuth, signInAnonymously } from "firebase/auth";
import { getDatabase, ref, get, set, push, remove, onValue, serverTimestamp, type Unsubscribe } from "firebase/database";
import { firebaseConfig, SESSION_MS } from "./firebase-config";

const $ = <T extends HTMLElement = HTMLElement>(id: string) => document.getElementById(id) as T;
const status = (t: string) => ($("status").textContent = t);

const app = initializeApp(firebaseConfig);
const db = getDatabase(app);
let uid = "";
let code = "";
let stops: Unsubscribe[] = [];
let skew = 0;
onValue(ref(db, ".info/serverTimeOffset"), (s) => (skew = Number(s.val()) || 0));
const now = () => Date.now() + skew;

async function signIn() {
  if (uid) return uid;
  const cred = await signInAnonymously(getAuth(app));
  uid = cred.user.uid;
  return uid;
}

function show(c: string, expires: number) {
  code = c;
  try { localStorage.setItem("hostCode", c); } catch { /* ignore */ }
  $("start-box").hidden = true;
  $("live-box").hidden = false;
  $("tools").hidden = false;
  $("code").textContent = c;
  const t = new Date(expires).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
  $("ends").textContent = `Ends at ${t}.`;
  stops.forEach((f) => f());
  stops = [
    onValue(ref(db, `sessions/${c}/who`), (s) => {
      const who = (s.val() ?? {}) as Record<string, { n?: string; p?: string; b?: number; dx?: number; lv?: number }>;
      const list = Object.values(who).sort((a, b) => String(a.n).localeCompare(String(b.n)));
      $("count").textContent = String(list.length);
      const ul = $("roster");
      ul.replaceChildren(...list.map((w) => {
        const li = document.createElement("li");
        const n = document.createElement("strong");
        n.textContent = w.n || "Player";
        const p = document.createElement("span");
        p.textContent = w.p || "";
        const st = document.createElement("span");
        st.className = "stats";
        if (w.dx != null) st.textContent = `🏅 ${w.b ?? 0} ${(w.b ?? 0) === 1 ? "seal" : "seals"} · 📖 ${w.dx} caught · ⭐ Lv ${w.lv ?? 0}`;
        li.append(n, p, st);
        return li;
      }));
      if (!list.length) {
        const li = document.createElement("li");
        li.className = "empty";
        li.textContent = "Nobody yet. When students join, they show up here.";
        ul.append(li);
      }
    }),
    onValue(ref(db, `sessions/${c}/expires`), (s) => {
      if (!s.exists() || Number(s.val()) <= now()) ended("This session has ended.");
    }),
  ];
}

function ended(msg: string) {
  stops.forEach((f) => f());
  stops = [];
  code = "";
  try { localStorage.removeItem("hostCode"); } catch { /* ignore */ }
  $("live-box").hidden = true;
  $("tools").hidden = true;
  $("start-box").hidden = false;
  status(msg);
}

// Class end time: defaults to 50 minutes from now, rounded to 5 minutes
const endInput = $<HTMLInputElement>("end-time");
{
  const d = new Date(Date.now() + 50 * 60000);
  d.setMinutes(Math.ceil(d.getMinutes() / 5) * 5, 0, 0);
  endInput.value = `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
}
/** The chosen end time as a timestamp, or an error message */
function chosenEnd(): number | string {
  const [h, m] = endInput.value.split(":").map(Number);
  if (!Number.isFinite(h) || !Number.isFinite(m)) return "Pick a time for class to end.";
  const d = new Date();
  d.setHours(h, m, 0, 0);
  const ms = d.getTime() - Date.now();
  if (ms <= 60000) return "Pick a time later than now.";
  if (ms > SESSION_MS) return "Pick a time within the next 3 hours.";
  return now() + ms;
}

$("start").onclick = async () => {
  const end = chosenEnd();
  if (typeof end === "string") { status(end); return; }
  status("Starting…");
  $<HTMLButtonElement>("start").disabled = true;
  try {
    await signIn();
    for (let tries = 0; tries < 20; tries++) {
      const c = String(1000 + Math.floor(Math.random() * 9000));
      const s = await get(ref(db, `sessions/${c}/expires`));
      if (s.exists() && Number(s.val()) > now()) continue; // in use by another class
      if (s.exists()) await remove(ref(db, `sessions/${c}`)).catch(() => {});
      const expires = Math.min(end, now() + SESSION_MS);
      try {
        await set(ref(db, `sessions/${c}`), { host: uid, created: serverTimestamp(), expires });
      } catch {
        continue; // someone else's old session: try another code
      }
      status("");
      show(c, expires);
      return;
    }
    status("Couldn't find a free code. Try again.");
  } catch (e) {
    console.error(e);
    status("Couldn't reach the class server. Check the internet and try again.");
  } finally {
    $<HTMLButtonElement>("start").disabled = false;
  }
};

$("end").onclick = async () => {
  if (!code) return;
  if (!confirm(`End class ${code}? Students will stop seeing each other.`)) return;
  try {
    await remove(ref(db, `sessions/${code}`));
    ended("Session ended.");
  } catch (e) {
    console.error(e);
    status("Couldn't end the session. Check the internet and try again.");
  }
};

// Reopening this page brings back a session you started (same browser)
(async () => {
  let saved = "";
  try { saved = localStorage.getItem("hostCode") ?? ""; } catch { /* ignore */ }
  if (!saved) return;
  try {
    await signIn();
    const host = (await get(ref(db, `sessions/${saved}/host`))).val();
    const expires = Number((await get(ref(db, `sessions/${saved}/expires`))).val());
    if (host === uid && expires > now()) show(saved, expires);
    else localStorage.removeItem("hostCode");
  } catch { /* offline: stay on the start screen */ }
})();

// ---------------------------------------------------------------- announcements and events
const flash = (id: string, text: string) => {
  $(id).textContent = text;
  setTimeout(() => { if ($(id).textContent === text) $(id).textContent = ""; }, 6000);
};
const sendEvent = async (ev: Record<string, unknown>, minutes: number, msgId: string, done: string) => {
  if (!code) return;
  try {
    const r = push(ref(db, `sessions/${code}/events`));
    await set(r, { ...ev, t: serverTimestamp(), dur: Math.round(minutes * 60000) });
    flash(msgId, done);
    return r.key;
  } catch (e) {
    console.error(e);
    flash(msgId, "Couldn't send. Check the internet and try again.");
    return null;
  }
};
const val = (id: string) => ($(id) as HTMLInputElement | HTMLSelectElement).value;

$<HTMLFormElement>("ann-form").onsubmit = async (e) => {
  e.preventDefault();
  const text = val("ann-text").trim();
  if (!text || !code) return;
  try {
    await set(ref(db, `sessions/${code}/announce`), { id: String(Date.now()), text, save: $<HTMLInputElement>("ann-save").checked, t: serverTimestamp() });
    $<HTMLTextAreaElement>("ann-text").value = "";
    flash("ann-msg", "Sent ✔");
  } catch (err) {
    console.error(err);
    flash("ann-msg", "Couldn't send. Check the internet and try again.");
  }
};

$<HTMLFormElement>("gift-form").onsubmit = (e) => {
  e.preventDefault();
  const sel = $<HTMLSelectElement>("gift-item");
  void sendEvent({ k: "gift", item: sel.value, qty: Number(val("gift-qty")) }, 0, "gift-msg",
    `Sent ${val("gift-qty")} × ${sel.options[sel.selectedIndex].text} ✔`);
};

$<HTMLFormElement>("bonus-form").onsubmit = (e) => {
  e.preventDefault();
  const min = Number(val("bonus-min"));
  void sendEvent({ k: "bonus" }, min, "bonus-msg", `Bonus time is on for ${min} minutes ✔`);
};

$<HTMLFormElement>("swarm-form").onsubmit = (e) => {
  e.preventDefault();
  const [map, place, level] = val("swarm-map").split("|");
  const mon = $<HTMLSelectElement>("swarm-mon");
  const min = Number(val("swarm-min"));
  void sendEvent({ k: "swarm", species: mon.value, map: Number(map), place, level: Number(level) }, min, "swarm-msg",
    `${mon.options[mon.selectedIndex].text} is in ${place} for ${min} minutes ✔`);
};

let stopAnswers: Unsubscribe | null = null;
$<HTMLFormElement>("q-form").onsubmit = async (e) => {
  e.preventDefault();
  const q = val("q-text").trim();
  const inputs = [...document.querySelectorAll<HTMLInputElement>(".q-choice")];
  const right = Number((document.querySelector<HTMLInputElement>('input[name="q-right"]:checked'))?.value ?? 0);
  const choices: string[] = [];
  let answer = -1;
  inputs.forEach((inp, i) => {
    const t = inp.value.trim();
    if (!t) return;
    if (i === right) answer = choices.length;
    choices.push(t);
  });
  if (!q || choices.length < 2) return flash("q-msg", "Write a question and at least two answers.");
  if (answer < 0) return flash("q-msg", "Mark the right answer (the circle next to it).");
  const key = await sendEvent({ k: "question", q, choices, answer, reward: val("q-reward") }, 5, "q-msg", "Asked ✔ Answers show below.");
  if (!key) return;
  stopAnswers?.();
  const results = $("q-results");
  stopAnswers = onValue(ref(db, `sessions/${code}/answers/${key}`), (s) => {
    const all = Object.values((s.val() ?? {}) as Record<string, { n?: string; ok?: boolean }>);
    const ok = all.filter((a) => a.ok).map((a) => a.n || "Player");
    const no = all.filter((a) => !a.ok).map((a) => a.n || "Player");
    results.replaceChildren();
    const p1 = document.createElement("p");
    p1.textContent = `"${q}": ${ok.length} right, ${no.length} not yet.`;
    results.append(p1);
    if (ok.length) { const p = document.createElement("p"); p.className = "names"; p.textContent = "✔ " + ok.join(", "); results.append(p); }
    if (no.length) { const p = document.createElement("p"); p.className = "names"; p.textContent = "✗ " + no.join(", "); results.append(p); }
  });
};
