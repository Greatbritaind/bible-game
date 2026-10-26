// Packs a game folder into bundles for the web player:  node scripts/pack.mjs <game folder> <output folder>
//
// Files are grouped by kind (map/event data, music, sprites, ...) so an update only changes the bundles
// whose files changed. Each bundle is an uncompressed ZIP named after a fingerprint of its contents, so
// players' browsers keep bundles they already have and download only new ones.
// Writes <output>/files/* (the bundles, plus Ruby if <output>/ruby.wasm exists) and <output>/manifest.json.
import { createHash } from "node:crypto";
import { mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync, existsSync } from "node:fs";
import { join, relative } from "node:path";
import { crc32, gzipSync } from "node:zlib";

const [gameDir, outDir] = process.argv.slice(2);
if (!gameDir || !outDir) {
  console.error("usage: node scripts/pack.mjs <game folder> <output folder>");
  process.exit(1);
}

/** Largest bundle; bigger groups are split into numbered parts (smaller pieces get through school filters better). */
const MAX_BUNDLE = 6 * 1024 * 1024;

// First matching rule wins. Paths are compared in lower case.
const GROUPS = [
  ["data", (p) => p.startsWith("data/") || !p.includes("/")], // maps, events, scripts, settings
  ["followers", (p) => p.startsWith("graphics/characters/followers")],
  ["characters", (p) => p.startsWith("graphics/characters/")],
  ["pokemon", (p) => p.startsWith("graphics/pokemon/")],
  ["maps", (p) => /^graphics\/(tilesets|autotiles|panoramas|fogs|battlebacks)\//.test(p)],
  ["animations", (p) => /^graphics\/(animations|battle animations)\//.test(p)],
  ["graphics", (p) => p.startsWith("graphics/")],
  ["music", (p) => p.startsWith("audio/bgm/")],
  ["sounds", (p) => p.startsWith("audio/")],
  ["other", () => true],
];
// soundfont.sf2 sits in the root but is big and never changes: give it its own bundle
const SPECIAL = { "soundfont.sf2": "soundfont" };

function walk(dir) {
  const out = [];
  for (const name of readdirSync(dir)) {
    const full = join(dir, name);
    if (statSync(full).isDirectory()) out.push(...walk(full));
    else out.push(full);
  }
  return out;
}

/** Uncompressed ZIP with fixed timestamps, so the same files always give the same bytes. */
function zip(entries) {
  const parts = [];
  const central = [];
  let offset = 0;
  const DOS_TIME = 0, DOS_DATE = (2020 - 1980) << 9 | 1 << 5 | 1;
  for (const { path, data } of entries) {
    const name = Buffer.from(path, "utf8");
    const crc = crc32(data) >>> 0;
    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0);
    local.writeUInt16LE(10, 4); // version needed
    local.writeUInt16LE(0x0800, 6); // UTF-8 names
    local.writeUInt16LE(0, 8); // stored
    local.writeUInt16LE(DOS_TIME, 10);
    local.writeUInt16LE(DOS_DATE, 12);
    local.writeUInt32LE(crc, 14);
    local.writeUInt32LE(data.length, 18);
    local.writeUInt32LE(data.length, 22);
    local.writeUInt16LE(name.length, 26);
    local.writeUInt16LE(0, 28);
    const cen = Buffer.alloc(46);
    cen.writeUInt32LE(0x02014b50, 0);
    cen.writeUInt16LE(20, 4);
    cen.writeUInt16LE(10, 6);
    cen.writeUInt16LE(0x0800, 8);
    cen.writeUInt16LE(0, 10);
    cen.writeUInt16LE(DOS_TIME, 12);
    cen.writeUInt16LE(DOS_DATE, 14);
    cen.writeUInt32LE(crc, 16);
    cen.writeUInt32LE(data.length, 20);
    cen.writeUInt32LE(data.length, 24);
    cen.writeUInt16LE(name.length, 28);
    cen.writeUInt32LE(offset, 42);
    central.push(cen, name);
    parts.push(local, name, data);
    offset += 30 + name.length + data.length;
  }
  const cenSize = central.reduce((n, b) => n + b.length, 0);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(entries.length, 8);
  end.writeUInt16LE(entries.length, 10);
  end.writeUInt32LE(cenSize, 12);
  end.writeUInt32LE(offset, 16);
  return Buffer.concat([...parts, ...central, end]);
}

const hash = (buf) => createHash("sha256").update(buf).digest("hex").slice(0, 12);

/** Writes a bundle, gzipped when that makes it at least 10% smaller. The browser unpacks it. */
function writeBundle(name, data, ext) {
  const packed = gzipSync(data, { level: 9 });
  const gz = packed.length < data.length * 0.9;
  // unusual extensions so the web server sends the bytes as they are
  const file = `files/${name}.${hash(data)}.${ext}${gz ? "z" : ""}`;
  writeFileSync(join(outDir, file), gz ? packed : data);
  return { name, file, size: data.length, bytes: gz ? packed.length : data.length, gz };
}

// Group the files
const groups = new Map();
for (const full of walk(gameDir)) {
  const path = relative(gameDir, full).split("\\").join("/");
  const lower = path.toLowerCase();
  const group = SPECIAL[lower] ?? GROUPS.find(([, test]) => test(lower))[0];
  if (!groups.has(group)) groups.set(group, []);
  groups.get(group).push({ path, full, size: statSync(full).size });
}

const filesDir = join(outDir, "files");
rmSync(filesDir, { recursive: true, force: true });
mkdirSync(filesDir, { recursive: true });

const bundles = [];
for (const [group] of [...GROUPS, ["soundfont"]]) {
  const list = groups.get(group);
  if (!list) continue;
  list.sort((a, b) => (a.path < b.path ? -1 : a.path > b.path ? 1 : 0));
  // split into parts of at most MAX_BUNDLE
  const chunks = [[]];
  let size = 0;
  for (const f of list) {
    if (size > 0 && size + f.size > MAX_BUNDLE) {
      chunks.push([]);
      size = 0;
    }
    chunks[chunks.length - 1].push(f);
    size += f.size;
  }
  chunks.forEach((chunk, i) => {
    const name = chunks.length > 1 ? `${group}-${i + 1}` : group;
    const data = zip(chunk.map((f) => ({ path: f.path, data: readFileSync(f.full) })));
    bundles.push(writeBundle(name, data, "mkxpz"));
  });
}

const manifest = { bundles };
const rubyPath = join(outDir, "ruby.wasm");
if (existsSync(rubyPath)) {
  manifest.ruby = writeBundle("ruby", readFileSync(rubyPath), "wasm");
}
writeFileSync(join(outDir, "manifest.json"), JSON.stringify(manifest, null, 1) + "\n");

const mb = (n) => (n / 1048576).toFixed(1).padStart(5) + " MB";
const all = manifest.ruby ? [manifest.ruby, ...bundles] : bundles;
for (const b of all) console.log(`${mb(b.bytes)} download, ${mb(b.size)} unpacked  ${b.file}`);
console.log(`${mb(all.reduce((n, b) => n + b.bytes, 0))} download in ${all.length} files`);
