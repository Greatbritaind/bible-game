// Game files: read an uncompressed .mkxpz/.zip archive without copying any file data,
// and expose it both to JavaScript (images, audio, fonts) and to Ruby (as a WASI file system).
import { Directory, File, Inode } from "@bjorn3/browser_wasi_shim";

/** Map with case-insensitive lookups, like the Windows file system RPG Maker games expect. */
export class CIMap extends Map<string, Inode> {
  private lower = new Map<string, string>();
  set(key: string, value: Inode) {
    this.lower.set(key.toLowerCase(), key);
    return super.set(key, value);
  }
  delete(key: string) {
    const real = this.realKey(key);
    if (real === undefined) return false;
    this.lower.delete(real.toLowerCase());
    return super.delete(real);
  }
  get(key: string) {
    const direct = super.get(key);
    if (direct !== undefined) return direct;
    const real = this.lower.get(key.toLowerCase());
    return real === undefined ? undefined : super.get(real);
  }
  has(key: string) {
    return this.get(key) !== undefined;
  }
  realKey(key: string) {
    return super.has(key) ? key : this.lower.get(key.toLowerCase());
  }
}

export class GameFiles {
  /** lower-case path -> file bytes */
  private files = new Map<string, Uint8Array>();
  /** lower-case path without extension -> list of real paths */
  private stems = new Map<string, string[]>();
  readonly root: Directory;

  constructor(archive: ArrayBuffer | SharedArrayBuffer) {
    const entries = readZip(archive);
    const rootMap = new CIMap();
    this.root = new Directory(rootMap);
    for (const [path, data] of entries) {
      const lower = path.toLowerCase();
      this.files.set(lower, data);
      const stem = lower.replace(/\.[^./]*$/, "");
      const list = this.stems.get(stem);
      if (list) list.push(path);
      else this.stems.set(stem, [path]);
      // Add to the directory tree
      const parts = path.split("/");
      let dir = this.root;
      for (const part of parts.slice(0, -1)) {
        let next = dir.contents.get(part);
        if (!(next instanceof Directory)) {
          next = new Directory(new CIMap());
          (next as unknown as { parent: Directory }).parent = dir;
          dir.contents.set(part, next);
        }
        dir = next as Directory;
      }
      const file = new File(new ArrayBuffer(0), { readonly: true });
      file.data = data; // share memory, no copy
      dir.contents.set(parts[parts.length - 1], file);
    }
  }

  /** Find a file by path, ignoring case and backslashes. */
  get(path: string): Uint8Array | undefined {
    return this.files.get(normalize(path).toLowerCase());
  }

  /** Find a file the way RPG Maker does: exact name first, then by trying extensions. */
  resolve(path: string, extensions: string[]): { path: string; data: Uint8Array } | null {
    const norm = normalize(path);
    const exact = this.files.get(norm.toLowerCase());
    if (exact) return { path: norm, data: exact };
    for (const ext of extensions) {
      const p = (norm + ext).toLowerCase();
      const data = this.files.get(p);
      if (data) return { path: norm + ext, data };
    }
    return null;
  }

  list(prefix: string): string[] {
    const p = normalize(prefix).toLowerCase();
    return [...this.files.keys()].filter((k) => k.startsWith(p));
  }
}

export const normalize = (path: string) =>
  path.replace(/\\/g, "/").replace(/^\.\//, "").replace(/\/+/g, "/");

/** Minimal ZIP reader for archives whose files are stored without compression. */
function readZip(buffer: ArrayBuffer | SharedArrayBuffer): Map<string, Uint8Array> {
  const view = new DataView(buffer);
  const bytes = new Uint8Array(buffer);
  // Find the end-of-central-directory record
  let eocd = -1;
  for (let i = buffer.byteLength - 22; i >= Math.max(0, buffer.byteLength - 65557); i--) {
    if (view.getUint32(i, true) === 0x06054b50) {
      eocd = i;
      break;
    }
  }
  if (eocd < 0) throw new Error("The game file is not a valid archive.");
  let count = view.getUint16(eocd + 10, true);
  let offset = view.getUint32(eocd + 16, true);
  // ZIP64 support for very large archives
  if (count === 0xffff || offset === 0xffffffff) {
    const loc = eocd - 20;
    if (view.getUint32(loc, true) === 0x07064b50) {
      const z64 = Number(view.getBigUint64(loc + 8, true));
      count = Number(view.getBigUint64(z64 + 32, true));
      offset = Number(view.getBigUint64(z64 + 48, true));
    }
  }
  const decoder = new TextDecoder();
  const out = new Map<string, Uint8Array>();
  for (let n = 0; n < count; n++) {
    if (view.getUint32(offset, true) !== 0x02014b50) throw new Error("Broken archive directory.");
    const method = view.getUint16(offset + 10, true);
    let compSize = view.getUint32(offset + 20, true);
    const nameLen = view.getUint16(offset + 28, true);
    const extraLen = view.getUint16(offset + 30, true);
    const commentLen = view.getUint16(offset + 32, true);
    let localOffset = view.getUint32(offset + 42, true);
    const name = decoder.decode(bytes.slice(offset + 46, offset + 46 + nameLen));
    // ZIP64 extra field
    let e = offset + 46 + nameLen;
    const eEnd = e + extraLen;
    while (e + 4 <= eEnd) {
      const id = view.getUint16(e, true);
      const size = view.getUint16(e + 2, true);
      if (id === 0x0001) {
        let p = e + 4;
        if (view.getUint32(offset + 24, true) === 0xffffffff) p += 8;
        if (compSize === 0xffffffff) {
          compSize = Number(view.getBigUint64(p, true));
          p += 8;
        }
        if (localOffset === 0xffffffff) localOffset = Number(view.getBigUint64(p, true));
      }
      e += 4 + size;
    }
    offset = eEnd + commentLen;
    if (name.endsWith("/")) continue;
    if (method !== 0) throw new Error(`"${name}" is compressed. Pack the game without compression.`);
    const lNameLen = view.getUint16(localOffset + 26, true);
    const lExtraLen = view.getUint16(localOffset + 28, true);
    const start = localOffset + 30 + lNameLen + lExtraLen;
    out.set(normalize(name), bytes.subarray(start, start + compSize));
  }
  return out;
}
