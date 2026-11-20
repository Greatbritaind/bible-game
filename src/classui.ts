// ☰ → Class: join the class session your teacher started (a 4-digit code), or leave it.
// Also the 😄 emote picker and the teacher's announcements.
import { ClassPlay } from "./mp";
import type { SharedBuffers } from "./shared";

const $ = <T extends HTMLElement = HTMLElement>(id: string) => document.getElementById(id) as T;

export function setupClass(shared: SharedBuffers, toast: (m: string, ms?: number) => void, voice: { say: (t: string) => void; read: (t: string) => void }, test: boolean) {
  const play = new ClassPlay(shared, test);
  const pop = $("class-pop");
  const form = $<HTMLFormElement>("class-form");
  const input = $<HTMLInputElement>("class-code");
  const msg = $("class-msg");
  const btn = $("hud-class");
  const emoteBtn = $("hud-emote");
  const emotePop = $("emote-pop");
  const focusGame = () => $<HTMLCanvasElement>("screen").focus();
  const render = () => {
    $("class-in").hidden = !play.joined;
    $("class-out").hidden = play.joined;
    if (play.joined) {
      $("class-which").textContent = play.classCode;
      $("class-here").textContent = play.here === 0 ? "No classmates on this map right now."
        : play.here === 1 ? "1 classmate is on this map." : `${play.here} classmates are on this map.`;
    }
    btn.setAttribute("data-label", play.joined ? `Class ${play.classCode}` : "Join class");
    btn.classList.toggle("on", play.joined);
    emoteBtn.hidden = !play.joined;
    if (!play.joined) emotePop.hidden = true;
  };
  play.onChange = render;
  play.onEnded = () => toast("The class session ended.", 4000);

  // teacher announcements
  const box = $("announce");
  let annText = "";
  play.onAnnounce = (a) => {
    annText = a.text;
    $("announce-text").textContent = a.text;
    $("announce-save").hidden = !a.save;
    box.hidden = false;
    voice.say("Message from your teacher. " + a.text);
  };
  $("announce-ok").onclick = () => { box.hidden = true; focusGame(); };
  $("announce-read").onclick = () => voice.read(annText);

  form.onsubmit = async (e) => {
    e.preventDefault();
    msg.textContent = "Joining…";
    const r = await play.join(input.value);
    if (r === "ok") {
      msg.textContent = "";
      input.value = "";
      toast(`You joined class ${play.classCode}! 👥`, 3000);
      pop.hidden = true;
      focusGame();
    } else if (r === "nocode") msg.textContent = "No class with that code. Check the code and try again.";
    else msg.textContent = "Couldn't reach the class server. Check the internet and try again.";
  };
  input.addEventListener("input", () => (input.value = input.value.replace(/\D/g, "").slice(0, 4)));
  $("class-leave").onclick = () => { play.leave(); toast("You left the class.", 2500); };
  $("class-done").onclick = () => (pop.hidden = true);
  $("class-done2").onclick = () => (pop.hidden = true);

  // emotes
  for (const b of emotePop.querySelectorAll<HTMLButtonElement>(".emote-btn")) {
    b.onclick = () => { play.emote(Number(b.dataset.e)); emotePop.hidden = true; focusGame(); };
  }
  $("emote-done").onclick = () => { emotePop.hidden = true; focusGame(); };

  render();
  // Rejoin after a reload (the code is kept for 3 hours)
  const saved = play.savedCode();
  if (saved) void play.join(saved).then((r) => { if (r === "ok") toast(`Back in class ${saved} 👥`, 2500); });
  return {
    play,
    toggle() {
      pop.hidden = !pop.hidden;
      msg.textContent = "";
      render();
      if (!pop.hidden && !play.joined) setTimeout(() => input.focus(), 50);
    },
    toggleEmotes() { emotePop.hidden = !emotePop.hidden; },
  };
}
