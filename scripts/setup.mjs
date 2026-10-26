// Copies Ruby (WebAssembly) into public/ so the page can download it.
import { copyFileSync } from "node:fs";
copyFileSync("node_modules/@ruby/3.3-wasm-wasi/dist/ruby+stdlib.wasm", "public/ruby.wasm");
console.log("Copied ruby.wasm into public/");
