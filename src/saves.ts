// Save files, kept in the browser's IndexedDB (one record per file, grouped by game).
const DB = "bible-player-saves";

function open(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB, 1);
    req.onupgradeneeded = () => req.result.createObjectStore("files");
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

export async function load(game: string): Promise<[string, Uint8Array][]> {
  try {
    const db = await open();
    const out: [string, Uint8Array][] = [];
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction("files", "readonly");
      const req = tx.objectStore("files").openCursor();
      req.onsuccess = () => {
        const c = req.result;
        if (!c) return resolve();
        const [g, name] = String(c.key).split("\u0000");
        if (g === game) out.push([name, new Uint8Array(c.value as ArrayBuffer)]);
        c.continue();
      };
      req.onerror = () => reject(req.error);
    });
    db.close();
    return out;
  } catch (e) {
    console.warn("Saves could not be read", e);
    return [];
  }
}

export async function store(game: string, name: string, data: Uint8Array | null) {
  try {
    const db = await open();
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction("files", "readwrite");
      const key = game + "\u0000" + name;
      if (data) tx.objectStore("files").put(data.slice().buffer, key);
      else tx.objectStore("files").delete(key);
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
    db.close();
  } catch (e) {
    console.warn("Save could not be stored", e);
  }
}
