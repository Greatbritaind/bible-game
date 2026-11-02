// Writes the password file for the start screen:  GAME_PASSWORD=... node scripts/password.mjs public/access.json
// (Without GAME_PASSWORD it keeps an existing access.json; add --clear to remove the password.)
// Only a fingerprint (SHA-256) of the password is published, never the password itself. With no
// GAME_PASSWORD the game has no password. The salt is fixed so the fingerprint only changes when the
// password does (changing it makes every computer ask for the new one).
// Must match normalizePassword() in src/main.ts: case, spaces and punctuation don't matter.
import { createHash } from "node:crypto";
import { existsSync, writeFileSync } from "node:fs";

const out = process.argv[2] ?? "public/access.json";
const normalize = (s) => s.toLowerCase().replace(/[^\p{L}\p{N}]/gu, "");
const password = normalize(process.env.GAME_PASSWORD ?? "");
if (!password && existsSync(out) && !process.argv.includes("--clear")) {
  // no GAME_PASSWORD secret: keep the committed public/access.json
  console.log(`Using the password fingerprint already in ${out}.`);
  process.exit(0);
}
const salt = "road-to-jerusalem";
const access = password ? { salt, hash: createHash("sha256").update(`${salt}:${password}`).digest("hex") } : {};
writeFileSync(out, JSON.stringify(access) + "\n");
console.log(password ? "Password is set." : "No password: the game is open to everyone.");
