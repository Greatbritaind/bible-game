// Keyboard controls that players can change. The game itself only knows the standard keys
// (see BINDINGS in rgss.rb), so a chosen key is translated into the standard key for its action.
// Enter, Esc and Backspace always keep working (typing names and codes needs them).

type Action = "up" | "down" | "left" | "right" | "talk" | "back" | "menu" | "ready" | "pageUp" | "pageDown";

interface ActionInfo {
  id: Action;
  label: string;
  key: string; // the standard key the game knows for this action
}

const ACTIONS: ActionInfo[] = [
  { id: "up", label: "Walk up", key: "ArrowUp" },
  { id: "down", label: "Walk down", key: "ArrowDown" },
  { id: "left", label: "Walk left", key: "ArrowLeft" },
  { id: "right", label: "Walk right", key: "ArrowRight" },
  { id: "talk", label: "Action", key: "KeyC" },
  { id: "back", label: "Back · hold to run", key: "KeyX" },
  { id: "menu", label: "Menu", key: "KeyZ" },
  { id: "ready", label: "Quick items", key: "KeyD" },
  { id: "pageUp", label: "Page up", key: "KeyQ" },
  { id: "pageDown", label: "Page down", key: "KeyW" },
];

const DEFAULTS: Record<Action, string[]> = {
  up: ["ArrowUp"],
  down: ["ArrowDown"],
  left: ["ArrowLeft"],
  right: ["ArrowRight"],
  talk: ["KeyC", "Space"],
  back: ["KeyX"],
  menu: ["KeyZ", "ShiftLeft", "ShiftRight"],
  ready: ["KeyD"],
  pageUp: ["KeyQ", "PageUp"],
  pageDown: ["KeyW", "PageDown"],
};

// Keys that can't be chosen (they always do their normal job)
const FIXED = new Set(["Enter", "NumpadEnter", "Escape", "Backspace", "Tab", "MetaLeft", "MetaRight", "CapsLock"]);
const STORE = "keyboardKeys";

const ALL_DEFAULT_KEYS = new Set(Object.values(DEFAULTS).flat());

export function keyName(code: string): string {
  const named: Record<string, string> = {
    ArrowUp: "↑", ArrowDown: "↓", ArrowLeft: "←", ArrowRight: "→", Space: "Space",
    ShiftLeft: "Shift", ShiftRight: "Right Shift", ControlLeft: "Ctrl", ControlRight: "Right Ctrl",
    AltLeft: "Alt", AltRight: "Right Alt", PageUp: "Page Up", PageDown: "Page Down",
    Semicolon: ";", Quote: "'", Comma: ",", Period: ".", Slash: "/", Backslash: "\\",
    BracketLeft: "[", BracketRight: "]", Minus: "-", Equal: "=", Backquote: "`",
  };
  if (named[code]) return named[code];
  if (/^Key[A-Z]$/.test(code)) return code.slice(3);
  if (/^Digit\d$/.test(code)) return code.slice(5);
  if (/^Numpad/.test(code)) return "Num " + code.slice(6);
  return code;
}

function loadMap(): Record<Action, string[]> {
  const map = structuredClone(DEFAULTS);
  try {
    const saved = JSON.parse(localStorage.getItem(STORE) ?? "null");
    if (saved && typeof saved === "object") {
      for (const a of ACTIONS) {
        const v = saved[a.id];
        if (Array.isArray(v) && v.every((k) => typeof k === "string" && k.length < 30)) map[a.id] = v;
      }
    }
  } catch {
    // no storage: use the defaults
  }
  return map;
}

function saveMap(map: Record<Action, string[]>) {
  try {
    localStorage.setItem(STORE, JSON.stringify(map));
  } catch {
    // kept until the tab closes
  }
}

export function setupKeymap() {
  let map = loadMap();
  let lookup = new Map<string, string>(); // physical key -> standard key
  const rebuild = () => {
    lookup = new Map();
    for (const a of ACTIONS) for (const k of map[a.id]) lookup.set(k, a.key);
  };
  rebuild();

  let waitingFor: Action | null = null;
  let waitTimer = 0;
  const pop = document.getElementById("keys-pop")!;
  const list = document.getElementById("keys-list")!;
  const note = document.getElementById("keys-note")!;

  function render() {
    list.textContent = "";
    for (const a of ACTIONS) {
      const row = document.createElement("div");
      row.className = "pad-row";
      const label = document.createElement("span");
      label.className = "pad-label";
      label.textContent = a.label;
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "pad-assign";
      const names = map[a.id].map(keyName).join(" or ") || "None";
      btn.textContent = waitingFor === a.id ? "Press a key…" : names;
      btn.classList.toggle("waiting", waitingFor === a.id);
      btn.setAttribute("aria-label", `${a.label}: ${names}. Click to change.`);
      btn.onclick = () => {
        waitingFor = waitingFor === a.id ? null : a.id;
        note.textContent = "";
        clearTimeout(waitTimer);
        if (waitingFor) waitTimer = window.setTimeout(() => ((waitingFor = null), render()), 10000);
        render();
      };
      row.append(label, btn);
      list.append(row);
    }
  }

  function assign(action: Action, code: string) {
    const old = map[action];
    // if another action had this key, it gets this action's old keys (a swap), so nothing is left without a key
    for (const a of ACTIONS) {
      if (a.id === action || !map[a.id].includes(code)) continue;
      const rest = map[a.id].filter((k) => k !== code);
      map[a.id] = rest.length ? rest : old.filter((k) => k !== code);
    }
    map[action] = [code];
    saveMap(map);
    rebuild();
    waitingFor = null;
    clearTimeout(waitTimer);
    render();
  }

  // Catch the key for the action being changed before the game sees it
  window.addEventListener(
    "keydown",
    (e) => {
      if (!waitingFor) return;
      e.preventDefault();
      e.stopImmediatePropagation();
      if (e.code === "Escape") {
        waitingFor = null;
        render();
        return;
      }
      if (FIXED.has(e.code) || !e.code) {
        note.textContent = `${e.key} can't be changed. Pick another key.`;
        return;
      }
      note.textContent = "";
      assign(waitingFor, e.code);
    },
    true,
  );

  document.getElementById("keys-reset")!.onclick = () => {
    map = structuredClone(DEFAULTS);
    saveMap(map);
    rebuild();
    waitingFor = null;
    note.textContent = "";
    render();
  };
  document.getElementById("keys-done")!.onclick = () => {
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
    /** The key to send to the game for a key the player pressed, or null to ignore it. */
    translate(code: string): string | null {
      const mapped = lookup.get(code);
      if (mapped) return mapped;
      // a standard key the player moved to something else no longer does its old job
      if (ALL_DEFAULT_KEYS.has(code)) return null;
      return code;
    },
    toggle() {
      pop.hidden = !pop.hidden;
      waitingFor = null;
      note.textContent = "";
      if (!pop.hidden) render();
    },
  };
}
