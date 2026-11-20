// The teacher's page for class sessions: start a session to get a 4-digit code, watch who joined,
// and end it. Students join from the game (☰ → 👥 Join class).
import "@fontsource/atkinson-hyperlegible/400.css";
import "@fontsource/atkinson-hyperlegible/700.css";
import "./host.css";
import { initializeApp } from "firebase/app";
import { getAuth, signInAnonymously } from "firebase/auth";
import { getDatabase, ref, get, set, remove, onValue, serverTimestamp, type Unsubscribe } from "firebase/database";
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
  $("code").textContent = c;
  const t = new Date(expires).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
  $("ends").textContent = `Ends at ${t}.`;
  stops.forEach((f) => f());
  stops = [
    onValue(ref(db, `sessions/${c}/who`), (s) => {
      const who = (s.val() ?? {}) as Record<string, { n?: string; p?: string }>;
      const list = Object.values(who).sort((a, b) => String(a.n).localeCompare(String(b.n)));
      $("count").textContent = String(list.length);
      const ul = $("roster");
      ul.replaceChildren(...list.map((w) => {
        const li = document.createElement("li");
        const n = document.createElement("strong");
        n.textContent = w.n || "Player";
        const p = document.createElement("span");
        p.textContent = w.p || "";
        li.append(n, p);
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
  $("start-box").hidden = false;
  status(msg);
}

$("start").onclick = async () => {
  status("Starting…");
  $<HTMLButtonElement>("start").disabled = true;
  try {
    await signIn();
    for (let tries = 0; tries < 20; tries++) {
      const c = String(1000 + Math.floor(Math.random() * 9000));
      const s = await get(ref(db, `sessions/${c}/expires`));
      if (s.exists() && Number(s.val()) > now()) continue; // in use by another class
      if (s.exists()) await remove(ref(db, `sessions/${c}`)).catch(() => {});
      const expires = now() + SESSION_MS;
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
    const s = await get(ref(db, `sessions/${saved}`));
    const v = s.val() as { host?: string; expires?: number } | null;
    if (v && v.host === uid && Number(v.expires) > now()) show(saved, Number(v.expires));
    else localStorage.removeItem("hostCode");
  } catch { /* offline: stay on the start screen */ }
})();
