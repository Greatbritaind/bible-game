// Road to Jerusalem – trade mailbox
// Holds one Pokémon per trade code. A code can be picked up exactly once.
// Needs a D1 database connected to this Worker with the variable name DB.

const DAYS = 24 * 60 * 60 * 1000;
const CLAIM_DAYS = 7;   // a code can be picked up for this many days
const KEEP_DAYS = 60;   // after this, forgotten trades are deleted
const MAX_SIZE = 8000;  // largest Pokémon we accept (characters)

// Short, easy words for codes like LAMB-FIG-4
const WORDS = [
  "LAMB", "FIG", "FISH", "BOAT", "NET", "BREAD", "SEED", "VINE", "STAR", "LAMP",
  "OIL", "SALT", "ROCK", "WELL", "TENT", "DOVE", "SEA", "HILL", "SUN", "MOON",
  "ROBE", "COIN", "JAR", "CUP", "KEY", "DOOR", "ROAD", "TREE", "LEAF", "BIRD",
  "GOAT", "OX", "COW", "HORN", "HARP", "DRUM", "BELL", "RING", "GOLD", "PATH",
  "SAND", "RAIN", "WIND", "FIRE", "SNOW", "NEST", "WHEAT", "GATE", "WALL", "BOX",
  "BAG", "HAT", "MAP", "OAK", "PALM", "ROSE", "LILY", "MINT", "HONEY", "MILK",
  "EGG", "PEAR", "PLUM", "CORN",
];

const HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
  "Cross-Origin-Resource-Policy": "cross-origin",
  "Content-Type": "application/json",
};

const reply = (data, status = 200) => new Response(JSON.stringify(data), { status, headers: HEADERS });

function randomInt(n) {
  const a = new Uint32Array(1);
  crypto.getRandomValues(a);
  return a[0] % n;
}

function newCode() {
  return WORDS[randomInt(WORDS.length)] + "-" + WORDS[randomInt(WORDS.length)] + "-" + (1 + randomInt(9));
}

function newSecret() {
  const a = new Uint8Array(16);
  crypto.getRandomValues(a);
  return [...a].map((b) => b.toString(16).padStart(2, "0")).join("");
}

// Accepts "lamb fig 4", "Lamb-Fig-4", "LAMBFIG4"... and returns "LAMB-FIG-4" when possible
function cleanCode(text) {
  const t = String(text || "").toUpperCase().replace(/[^A-Z0-9]/g, "");
  const m = t.match(/^([A-Z]+)([1-9])$/);
  if (!m) return null;
  for (const a of WORDS) {
    if (!m[1].startsWith(a)) continue;
    const b = m[1].slice(a.length);
    if (WORDS.includes(b)) return `${a}-${b}-${m[2]}`;
  }
  return null;
}

async function setup(db) {
  await db.prepare(
    "CREATE TABLE IF NOT EXISTS trades (code TEXT PRIMARY KEY, secret TEXT NOT NULL, pokemon TEXT NOT NULL, created INTEGER NOT NULL)"
  ).run();
}

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") return new Response(null, { headers: HEADERS });
    if (!env.DB) return reply({ ok: false, message: "The database is not connected to this Worker yet." }, 500);
    const db = env.DB;
    await setup(db);
    const now = Date.now();

    if (request.method === "GET") {
      return reply({ ok: true, message: "The Road to Jerusalem trade mailbox is running." });
    }
    if (request.method !== "POST") return reply({ ok: false, message: "Not allowed" }, 405);

    let body;
    try {
      body = JSON.parse(await request.text());
    } catch {
      return reply({ ok: false, message: "Bad request" }, 400);
    }
    const action = new URL(request.url).pathname.replace(/^\/+/, "");

    // Put a Pokémon in the mailbox. Returns the code to share and a secret the sender keeps.
    if (action === "send") {
      const pokemon = String(body.pokemon || "");
      if (!pokemon || pokemon.length > MAX_SIZE) return reply({ ok: false, message: "That Pokémon could not be sent." }, 400);
      await db.prepare("DELETE FROM trades WHERE created < ?").bind(now - KEEP_DAYS * DAYS).run();
      const secret = newSecret();
      for (let i = 0; i < 20; i++) {
        const code = newCode();
        const r = await db
          .prepare("INSERT OR IGNORE INTO trades (code, secret, pokemon, created) VALUES (?, ?, ?, ?)")
          .bind(code, secret, pokemon, now)
          .run();
        if (r.meta.changes === 1) return reply({ ok: true, code, secret });
      }
      return reply({ ok: false, message: "The mailbox is busy. Try again." }, 503);
    }

    // Pick up a Pokémon. The row is removed in the same step, so a code only works once.
    if (action === "claim") {
      const code = cleanCode(body.code);
      if (!code) return reply({ ok: false, message: "That is not a trade code." });
      const row = await db
        .prepare("DELETE FROM trades WHERE code = ? AND created >= ? RETURNING pokemon")
        .bind(code, now - CLAIM_DAYS * DAYS)
        .first();
      if (!row) return reply({ ok: false, message: "No Pokémon is waiting for that code." });
      return reply({ ok: true, pokemon: row.pokemon });
    }

    // Sender checks on a trade: "waiting", "expired" (can be taken back) or "gone" (picked up).
    if (action === "status") {
      const row = await db.prepare("SELECT created FROM trades WHERE code = ? AND secret = ?")
        .bind(String(body.code || ""), String(body.secret || "")).first();
      if (!row) return reply({ ok: true, status: "gone" });
      return reply({ ok: true, status: row.created < now - CLAIM_DAYS * DAYS ? "expired" : "waiting" });
    }

    // Sender takes the Pokémon back (only the sender has the secret).
    if (action === "cancel") {
      const row = await db.prepare("DELETE FROM trades WHERE code = ? AND secret = ? RETURNING pokemon")
        .bind(String(body.code || ""), String(body.secret || "")).first();
      if (!row) return reply({ ok: false, message: "That trade was already picked up." });
      return reply({ ok: true, pokemon: row.pokemon });
    }

    return reply({ ok: false, message: "Not found" }, 404);
  },
};
