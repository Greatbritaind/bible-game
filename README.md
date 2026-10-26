# Bible Game player

Plays the RPG Maker XP / Pokémon Essentials game in `game/` in a web browser, including on school Chromebooks. Nothing needs to be installed.

## How it works

- **Ruby in the browser.** The official Ruby language, compiled to WebAssembly ([ruby.wasm](https://github.com/ruby/ruby.wasm)), runs the game's scripts (`Data/Scripts.rxdata`) unchanged.
- **Our own RPG Maker runtime.** `src/ruby/rgss.rb` and `src/engine.ts` provide what RPG Maker XP normally supplies: bitmaps, sprites, viewports, text, the keyboard, sound, and save files. They also cover the mkxp-z extras that Essentials uses.
- **A game thread.** The game runs in a Web Worker and sleeps between frames, so the page never freezes. That's why the page needs a small service worker (`coi-serviceworker.min.js`) on GitHub Pages.
- **Sound.** OGG/WAV play through Web Audio. MIDI plays through [SpessaSynth](https://github.com/spessasus/spessasynth_lib) with the game's own `soundfont.sf2`.
- **Saves** stay in each browser (IndexedDB). Students can download a save and load it on another Chromebook from the start screen.

## Updating the game

1. Copy your Essentials project over the `game/` folder: Data, Graphics, Audio, Fonts, Plugins, `mkxp.json`, `Game.ini` and `soundfont.sf2`. Windows files are fine to include, because the build removes them.
2. Commit and push to `main`. GitHub Desktop is the easiest way.
3. Wait for the green check on the **Actions** tab (a few minutes), then refresh the game page.

The build always names the game "Bible Game" (saves are stored under that name), whatever `mkxp.json` says.

## Controls

| Keys | Does |
| --- | --- |
| Arrow keys | Walk |
| C, Enter or Space | Talk / Yes |
| X, Esc or Backspace | Back (hold to run) |
| Z or Shift | Menu |

Touchscreens get on-screen buttons.

## Working on the player

```
npm install
npm run setup      # copies ruby.wasm into public/
# pack the game into public/game.mkxpz (stored, not compressed), e.g. with `rpzip -r`
npm run dev        # http://localhost:5173  (add ?debug for scene and timing logs)
npm run build      # static site in dist/
```

## Credits

- Ruby and ruby.wasm (Ruby License / MIT), SpessaSynth (Apache-2.0), browser_wasi_shim (MIT/Apache-2.0), coi-serviceworker (MIT), Atkinson Hyperlegible font (OFL).
- Pokémon Essentials by Maruno and contributors. Pokémon is © Nintendo / Game Freak / The Pokémon Company. This is a non-commercial classroom fan project.
