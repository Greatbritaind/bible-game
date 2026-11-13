# Modular Title Screen (Pokémon Essentials v21.1 Port)

A configurable, “layer-based” title screen system for **Pokémon Essentials v21.1**.

This port replaces the default Essentials title flow (`pbCallTitle`) with a modular title scene that can combine:

- A background (static, scrolling, sprite-sheet, hue-cycle, or frame-by-frame animation)
- Optional particle effects (embers/snow/spores/sparkles/light rays)
- Optional overlay layer (fog/scanlines/rain/etc.)
- One or two logos + optional glow/shine/sparkles
- Optional splash screens before the title
- Optional “Start” sound + distortion effect during the delay

## Requirements

- Pokémon Essentials **v21.1**
- RPG Maker XP

## Install

1. Copy the folder **`Modular Title Screen v21`** into your project’s `Plugins/` folder.
2. Create this graphics folder if it doesn’t exist:

   - `Graphics/MODTS/`

3. Add the required graphics listed below.
4. Configure options in `Plugins/Modular Title Screen v21/Config.rb`.
5. Launch the game.

### Compatibility note

This plugin **overrides** `pbCallTitle` (see the bottom of the plugin’s scene file). If you have other plugins that also override the title call, you’ll need to decide which one should “win” (load order matters).

## What files do I need?

### Required

These are loaded unconditionally and should exist to avoid errors:

- `Graphics/MODTS/logo.png` (or whatever you set `LOGO_FILE` to)
- `Graphics/MODTS/start.png` (the “Press Start” graphic)

### Recommended defaults (depending on what you enable)

**Backgrounds** (when `BACKGROUND_FILE = nil`):

- `Graphics/MODTS/bg0.png` (static)
- `Graphics/MODTS/bg1.png` (horizontal scroll)
- `Graphics/MODTS/bg2.png` (vertical scroll)
- `Graphics/MODTS/bg3.png` (sprite-sheet animation)
- `Graphics/MODTS/bg4.png` (hue-cycle)

If `bg0` is missing, the plugin will try `Graphics/Titles/title` as a fallback.

**Overlay** (when enabled):

- `Graphics/MODTS/overlay.png` (fallback)
- `Graphics/MODTS/overlay1.png` / `overlay2.png` / `overlay3.png` (type-specific defaults)

**Logo effects** (only if enabled in config):

- Glow: `Graphics/MODTS/logo_glow.png`
- Shine: `Graphics/MODTS/logo_shine.png`
- Sparkles: `Graphics/MODTS/sparkle.png`

**Particles** (only if enabled in config):

- Rising particles: `Graphics/MODTS/particle1.png`
- Falling particles: `Graphics/MODTS/particle2.png`
- Floating particles: `Graphics/MODTS/particle3.png`
- Sparkle particles: `Graphics/MODTS/sparkle.png`
- Light rays: `Graphics/MODTS/ray.png`

**Secondary logo** (only if enabled):

- `Graphics/MODTS/logo2.png` (or whatever you set `LOGO2_FILE` to)

**Splash screens** (only if enabled):

- `Graphics/MODTS/splash1.png`, `splash2.png`, etc. (whatever names you put in `SPLASH_IMAGES`)

## Configuration (Config.rb)

All configuration lives in `Plugins/Modular Title Screen v21/Config.rb`.

### Quick presets (recommended)

This port includes a `PRESET` switch at the top of `Config.rb` so you can quickly swap between a few showcase configurations for screenshots.

- Set `PRESET = :showcase_default` (nice-looking default)
- Other included presets: `:showcase_scrolling_fog`, `:showcase_digital_glitch`, `:showcase_light_rays`, `:showcase_animated_frames`


### Background

Set `BACKGROUND_TYPE`:

- `0` Static image (`bg0.png`)
- `1` Horizontal scroll (`bg1.png`, tiles left/right)
- `2` Vertical scroll (`bg2.png`, tiles up/down)
- `3` Sprite-sheet animation (`bg3.png`, frames **side-by-side**)
- `4` Hue-cycle effect (`bg4.png`, color tone cycles)
- `5` Frame animation (loads numbered frames from a folder)

Optional: set `BACKGROUND_FILE` to force a specific image.

- `BACKGROUND_FILE = "mybg"` loads `Graphics/MODTS/mybg.png`
- Subfolders are allowed: `BACKGROUND_FILE = "Backgrounds/clouded"` loads `Graphics/MODTS/Backgrounds/clouded.png`

#### Sprite-sheet background (type 3) tips

For `BACKGROUND_TYPE = 3`, the plugin assumes:

- All frames are in one image, arranged horizontally.
- Each frame width is `Graphics.width`.

So a 3-frame 512px-wide game would expect a `bg3.png` that is `512 * 3 = 1536px` wide.

#### Frame animation background (type 5)

Set:

- `BACKGROUND_FOLDER` (subfolder inside `Graphics/MODTS/`)
- `BACKGROUND_FRAME_COUNT` (how many frames you *intend* to load)
- `BACKGROUND_FRAME_DELAY` (how many game frames to wait between frame swaps)

Frame naming must be 3-digit, zero-padded (PNG or GIF frames are both fine):

- `Graphics/MODTS/<BACKGROUND_FOLDER>/000.png`
- `Graphics/MODTS/<BACKGROUND_FOLDER>/001.png`
- `Graphics/MODTS/<BACKGROUND_FOLDER>/002.png`
- …

Notes:

- The loader will only use frames that actually exist.
- If no frames are found, it falls back to `bg0` or `Graphics/Titles/title`.

### Intro animation

`INTRO_ANIMATION` controls how the title elements appear:

- `0` Simple fade (default)
- `1` Logo slides down from top
- `2` Logo zooms in
- `3` White flash then fade
- `4` Logo slides in from left
- `5` Elements fade in one-by-one
- `6` Quick fade (with a brief “burst” moment)
- `7` Layered fade (background → effects/overlays → logo)

### Music

Set `TITLE_BGM` to the filename (no extension) in `Audio/BGM/`.

- Example: `TITLE_BGM = "Lace_MainTheme"`
- Set to `nil` to use the game’s default title BGM.

The plugin attempts to detect BGM length for looping/restarting the title when the BGM ends; if it can’t read the play time, it won’t force a restart.

### Logos

- `LOGO_FILE` is required (default: `"logo"`).
- `LOGO_POS = [x, y]`:
  - Use `nil` to keep defaults.
  - Default positioning is centered X and ~35% down the screen.

Secondary logo:

- `LOGO2_FILE = "logo2"` (set `nil` to disable)
- `LOGO2_OFFSET_Y` is pixels below the main logo.

### Logo effects

Toggle these booleans:

- `LOGO_GLOW` (requires `logo_glow.png`)
- `LOGO_SHINE` (requires `logo_shine.png`)
- `LOGO_SPARKLE` (requires `sparkle.png`)

### Particle effects

Choose `PARTICLE_EFFECT`:

- `0` None
- `1` Rising (embers/dust)
- `2` Falling (snow/ash)
- `3` Floating (spores/fireflies)
- `4` Sparkle twinkles
- `5` Light rays

If the particle image is missing, the plugin draws simple placeholder particles.

### Overlay

Choose `OVERLAY_TYPE`:

- `0` None
- `1` Horizontal scroll
- `2` Vertical scroll
- `3` Pulsing opacity

Optional: set `OVERLAY_FILE = "overlay"` to use a custom file.

### “Press Start” placement

`START_POS = [x, y]`:

- Default is centered X and ~85% down the screen.
- Set either value to a number to override it.

### Start sound + distortion

When the player presses Start, the plugin can play a sound (commonly a Pokémon cry or SFX), then wait before moving to the load screen.

- `START_SE` (filename in `Audio/SE/`, no extension; set `nil` to disable)
- `START_SE_VOLUME` (0–100)
- `START_SE_PITCH` (50–150)
- `START_SE_DELAY` (seconds)

During the delay, `CRY_DISTORTION` can apply a temporary visual effect:

- `0` None
- `1` Screen shake
- `2` Wave-like distortion
- `3` Flash pulse
- `4` Color shift
- `5` Glitch / “datamosh”-style corruption

Set intensity with `CRY_DISTORTION_POWER` (recommended 3–8).

### Splash screens

If `SKIP_SPLASH = false`, the plugin will display `SPLASH_IMAGES` in order, each with a fade-in/hold/fade-out.

- `SPLASH_IMAGES = ["splash1", "splash2"]`
- `SPLASH_FADE_TICKS` affects fade speed
- `SPLASH_DURATION` is how long each splash stays on screen (seconds)

## Controls / Title behavior

- **Start / confirm:** the title proceeds when the player presses Essentials confirm keys (`Input::USE` or `Input::ACTION`).
- **Delete save shortcut:** hold **Down + Back + Ctrl** to open the delete-save screen.
- If `$DEBUG` is true and `SHOW_IN_DEBUG = false`, the plugin will use the debug intro instead of the modular title.

## Common recipes

### 1) Simple static title

- `BACKGROUND_TYPE = 0`
- Add `Graphics/MODTS/bg0.png`
- Add `Graphics/MODTS/logo.png` and `Graphics/MODTS/start.png`

### 2) Scrolling fog overlay + falling ash

- `BACKGROUND_TYPE = 0` (or whatever you like)
- `OVERLAY_TYPE = 1` and `OVERLAY_FILE = "fog"` (requires `Graphics/MODTS/fog.png`)
- `PARTICLE_EFFECT = 2` (requires `Graphics/MODTS/particle2.png`, optional)

### 3) GIF-style animated background

- `BACKGROUND_TYPE = 5`
- `BACKGROUND_FOLDER = "MyAnim"`
- Put frames in `Graphics/MODTS/MyAnim/000.png`, `001.png`, …
- Set `BACKGROUND_FRAME_DELAY = 2` for ~30fps

## Troubleshooting

### Crash on boot / black screen

Most commonly missing required graphics:

- Ensure `Graphics/MODTS/logo.png` (or your configured `LOGO_FILE`) exists.
- Ensure `Graphics/MODTS/start.png` exists.

### My animated background doesn’t animate (type 5)

- Confirm frames are named `000.png`, `001.png`, etc. (three digits).
- Confirm they are in `Graphics/MODTS/<BACKGROUND_FOLDER>/`.
- Confirm `BACKGROUND_FRAME_COUNT` is at least as high as your highest frame number + 1.

### Overlay doesn’t appear

- Make sure `OVERLAY_TYPE` is not 0.
- Make sure your overlay file exists (either `overlay.png` or your `OVERLAY_FILE`).

### Conflicts with other title plugins

Because this plugin overrides `pbCallTitle`, other plugins that also redefine it can conflict.

- Try moving this plugin folder earlier/later in load order.
- Ensure only one `pbCallTitle` override is active.

## Uninstall

- Delete `Plugins/Modular Title Screen v21/`.
- Remove any `Graphics/MODTS/` assets you no longer need.

## Credits

See `Plugins/Modular Title Screen v21/meta.txt` for the full credit list.

---

If you want, tell me what features you consider “core” for your port (e.g., frame animation + glitch start effect), and I can add a short “Quick Start: recommended defaults” section tailored to that style without changing any code.