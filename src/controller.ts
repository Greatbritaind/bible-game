// Game controllers (Xbox, PlayStation, Switch, 8BitDo, ...) through the browser's Gamepad API.
//
// Pairing happens in the computer's Bluetooth settings (or with a cable). The browser only sees a
// controller after one of its buttons is pressed. The D-pad and left stick always walk; the other
// game buttons can be changed in the 🎮 panel, and the choice is kept in this browser.

type Action = "talk" | "back" | "menu" | "ready" | "pageUp" | "pageDown";

interface ActionInfo {
  id: Action;
  label: string;
  key: string; // keyboard key the game already knows (see BINDINGS in rgss.rb)
}

const ACTIONS: ActionInfo[] = [
  { id: "talk", label: "Action", key: "KeyC" },
  { id: "back", label: "Back · hold to run", key: "KeyX" },
  { id: "menu", label: "Menu", key: "KeyZ" },
  { id: "ready", label: "Quick items", key: "KeyD" },
  { id: "pageUp", label: "Page up", key: "KeyQ" },
  { id: "pageDown", label: "Page down", key: "KeyW" },
];

// Button numbers in the browser's standard layout (positions, not letters)
const DEFAULTS: Record<Action, number[]> = {
  talk: [0], // bottom face button (A on Xbox, ✕ on PlayStation)
  back: [1], // right face button (B on Xbox, ○ on PlayStation)
  menu: [9, 3], // Start, and the top face button
  ready: [2], // left face button
  pageUp: [4], // left shoulder
  pageDown: [5], // right shoulder
};

const DPAD: [number, string][] = [
  [12, "ArrowUp"],
  [13, "ArrowDown"],
  [14, "ArrowLeft"],
  [15, "ArrowRight"],
];
const STICK = 0.5; // how far the stick must be pushed to walk
const STORE = "controllerButtons";

const BUTTON_NAMES: Record<number, string> = {
  0: "Bottom button",
  1: "Right button",
  2: "Left button",
  3: "Top button",
  4: "Left bumper",
  5: "Right bumper",
  6: "Left trigger",
  7: "Right trigger",
  8: "Select / Back",
  9: "Start",
  10: "Left stick click",
  11: "Right stick click",
  12: "D-pad up",
  13: "D-pad down",
  14: "D-pad left",
  15: "D-pad right",
  16: "Home",
};
const buttonName = (n: number) => BUTTON_NAMES[n] ?? `Button ${n + 1}`;

function loadMap(): Record<Action, number[]> {
  const map = structuredClone(DEFAULTS);
  try {
    const saved = JSON.parse(localStorage.getItem(STORE) ?? "null");
    if (saved && typeof saved === "object") {
      for (const a of ACTIONS) {
        const v = saved[a.id];
        if (Array.isArray(v) && v.every((n) => Number.isInteger(n) && n >= 0 && n < 32)) map[a.id] = v;
      }
    }
  } catch {
    // no storage: use the defaults
  }
  return map;
}

function saveMap(map: Record<Action, number[]>) {
  try {
    localStorage.setItem(STORE, JSON.stringify(map));
  } catch {
    // not kept in this browser; still works until the tab closes
  }
}

export function setupController(opts: {
  press: (code: string, down: boolean) => void;
  toast: (message: string, ms?: number) => void;
  onActivity: () => void;
}) {
  const { press, toast } = opts;
  let map = loadMap();
  const held = new Set<string>(); // keys this module is holding down in the game
  let lastButtons: boolean[] = [];
  let waitingFor: Action | null = null; // the panel is waiting for a button for this action
  let waitTimer = 0;

  const pop = document.getElementById("pad-pop")!;
  const list = document.getElementById("pad-list")!;
  const status = document.getElementById("pad-status")!;

  const connected = () => [...(navigator.getGamepads?.() ?? [])].filter((g): g is Gamepad => !!g && g.connected);

  const cleanName = (id: string) =>
    id
      .replace(/\(.*?\)/g, "")
      .replace(/Vendor:.*$/i, "")
      .trim() || "Controller";

  function renderStatus() {
    const pads = connected();
    status.textContent = pads.length
      ? `✅ Connected: ${cleanName(pads[0].id)}`
      : "No controller yet. Pair it in Bluetooth settings or plug it in, then press any button on it.";
  }

  function render() {
    renderStatus();
    list.textContent = "";
    for (const a of ACTIONS) {
      const row = document.createElement("div");
      row.className = "pad-row";
      row.dataset.action = a.id;
      const label = document.createElement("span");
      label.className = "pad-label";
      label.textContent = a.label;
      const btn = document.createElement("button");
      btn.className = "pad-assign";
      btn.type = "button";
      btn.textContent = waitingFor === a.id ? "Press a button…" : map[a.id].map(buttonName).join(" + ") || "None";
      btn.classList.toggle("waiting", waitingFor === a.id);
      btn.setAttribute("aria-label", `${a.label}: ${btn.textContent}. Click to change.`);
      btn.onclick = () => {
        waitingFor = waitingFor === a.id ? null : a.id;
        clearTimeout(waitTimer);
        if (waitingFor) waitTimer = window.setTimeout(() => ((waitingFor = null), render()), 10000);
        render();
      };
      row.append(label, btn);
      list.append(row);
    }
  }

  function assign(action: Action, button: number) {
    for (const a of ACTIONS) map[a.id] = map[a.id].filter((n) => n !== button);
    map[action] = [button];
    saveMap(map);
    waitingFor = null;
    clearTimeout(waitTimer);
    render();
  }

  function flash(button: number) {
    if (pop.hidden) return;
    for (const a of ACTIONS) {
      if (!map[a.id].includes(button)) continue;
      const row = list.querySelector<HTMLElement>(`[data-action="${a.id}"]`);
      if (!row) continue;
      row.classList.remove("lit");
      void row.offsetWidth;
      row.classList.add("lit");
    }
  }

  function release() {
    for (const k of held) press(k, false);
    held.clear();
  }

  // Called every animation frame
  function poll() {
    const pads = connected();
    if (!pads.length) {
      if (held.size) release();
      lastButtons = [];
      return;
    }
    const want = new Set<string>();
    const buttons: boolean[] = [];
    for (const g of pads) {
      g.buttons.forEach((b, i) => (buttons[i] = buttons[i] || b.pressed || b.value > 0.5));
      const x = g.axes[0] ?? 0;
      const y = g.axes[1] ?? 0;
      if (y < -STICK) want.add("ArrowUp");
      if (y > STICK) want.add("ArrowDown");
      if (x < -STICK) want.add("ArrowLeft");
      if (x > STICK) want.add("ArrowRight");
    }
    // newly pressed buttons
    let any = false;
    buttons.forEach((on, i) => {
      if (!on || lastButtons[i]) return;
      any = true;
      flash(i);
      if (waitingFor && !DPAD.some(([n]) => n === i)) assign(waitingFor, i);
    });
    lastButtons = buttons;
    if (any) opts.onActivity();

    // while the settings panel is open, button presses only light up the list
    if (pop.hidden) {
      for (const [n, key] of DPAD) if (buttons[n]) want.add(key);
      for (const a of ACTIONS) if (map[a.id].some((n) => buttons[n])) want.add(a.key);
    }
    for (const k of held) if (!want.has(k)) press(k, false);
    for (const k of want) if (!held.has(k)) press(k, true);
    held.clear();
    for (const k of want) held.add(k);
  }

  window.addEventListener("gamepadconnected", (e) => {
    toast(`🎮 ${cleanName(e.gamepad.id)} connected! To change its buttons, open ☰ and choose Controller.`, 5000);
    if (!pop.hidden) render();
  });
  window.addEventListener("gamepaddisconnected", () => {
    release();
    toast("🎮 Controller disconnected.", 3000);
    if (!pop.hidden) render();
  });

  document.getElementById("pad-reset")!.onclick = () => {
    map = structuredClone(DEFAULTS);
    saveMap(map);
    waitingFor = null;
    render();
  };
  document.getElementById("pad-done")!.onclick = () => {
    waitingFor = null;
    pop.hidden = true;
  };
  // clicking anywhere outside the box (but not the ☰ menu) closes it
  document.addEventListener("pointerdown", (e) => {
    const t = e.target as HTMLElement;
    if (pop.hidden || pop.contains(t) || t.closest?.("#hud")) return;
    waitingFor = null;
    pop.hidden = true;
  });

  return {
    poll,
    toggle() {
      pop.hidden = !pop.hidden;
      if (!pop.hidden) release();
      waitingFor = null;
      if (!pop.hidden) render();
    },
  };
}
