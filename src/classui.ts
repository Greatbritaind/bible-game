// ☰ → Class: join the class session your teacher started (a 4-digit code), or leave it.
import { ClassPlay } from "./mp";
import type { SharedBuffers } from "./shared";

const $ = <T extends HTMLElement = HTMLElement>(id: string) => document.getElementById(id) as T;

export function setupClass(shared: SharedBuffers, toast: (m: string, ms?: number) => void, test: boolean) {
  const play = new ClassPlay(shared, test);
  const pop = $("class-pop");
  const form = $<HTMLFormElement>("class-form");
  const input = $<HTMLInputElement>("class-code");
  const msg = $("class-msg");
  const inBox = $("class-in");
  const outBox = $("class-out");
  const btn = $("hud-class");
  const render = () => {
    inBox.hidden = !play.joined;
    outBox.hidden = play.joined;
    if (play.joined) {
      $("class-which").textContent = play.classCode;
      $("class-here").textContent = play.here === 0 ? "No classmates on this map right now."
        : play.here === 1 ? "1 classmate is on this map." : `${play.here} classmates are on this map.`;
    }
    btn.setAttribute("data-label", play.joined ? `Class ${play.classCode}` : "Join class");
    btn.classList.toggle("on", play.joined);
  };
  play.onChange = render;
  play.onEnded = () => toast("The class session ended.", 4000);
  form.onsubmit = async (e) => {
    e.preventDefault();
    msg.textContent = "Joining…";
    const r = await play.join(input.value);
    if (r === "ok") {
      msg.textContent = "";
      input.value = "";
      toast(`You joined class ${play.classCode}! 👥`, 3000);
      pop.hidden = true;
      $<HTMLCanvasElement>("screen").focus();
    } else if (r === "nocode") msg.textContent = "No class with that code. Check the code and try again.";
    else msg.textContent = "Couldn't reach the class server. Check the internet and try again.";
  };
  input.addEventListener("input", () => (input.value = input.value.replace(/\D/g, "").slice(0, 4)));
  $("class-leave").onclick = () => {
    play.leave();
    toast("You left the class.", 2500);
  };
  $("class-done").onclick = () => (pop.hidden = true);
  $("class-done2").onclick = () => (pop.hidden = true);
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
  };
}
