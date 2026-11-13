#===============================================================================
#  Modular Title Screen Configuration
#  Adapted for Pokemon Essentials v21.1 by Lace
#===============================================================================
module ModularTitle
  #=============================================================================
  #  QUICK PRESETS
  #=============================================================================
  # Set PRESET to quickly switch between a few showcase configurations.
  # Set to nil to customize settings below individually.
  #
  # Examples:
  #   PRESET = :road_to_jerusalem
  #   PRESET = :showcase_default
  #   PRESET = :showcase_scrolling_fog
  #   PRESET = :showcase_digital_glitch
  #   PRESET = :showcase_light_rays
  #   PRESET = :showcase_animated_frames
  #
  # BACKGROUND_FILE / OVERLAY_FILE can include subfolders.
  #   e.g. "Backgrounds/clouded" loads Graphics/MODTS/Backgrounds/clouded.png
  #=============================================================================
  PRESET = :road_to_jerusalem
  PRESETS = {
    # Road to Jerusalem: swaying wheat field, slowly drifting clouds (overlay1 +
    # Zz_SlowClouds.rb), golden specks, glowing logo, game's own title music.
    :road_to_jerusalem => {
      :BACKGROUND_TYPE        => 5,
      :BACKGROUND_FILE        => nil,
      :BACKGROUND_FOLDER      => "Wheat",
      :BACKGROUND_FRAME_COUNT => 32,
      :BACKGROUND_FRAME_DELAY => 3,
      :INTRO_ANIMATION        => 7,
      :TITLE_BGM              => nil,
      :LOGO_FILE              => "logo",
      :LOGO2_FILE             => "logo2",
      :LOGO_POS               => [nil, 86],
      :LOGO2_OFFSET_Y         => 150,
      :LOGO_GLOW              => true,
      :LOGO_SHINE             => true,
      :LOGO_SPARKLE           => false,
      :PARTICLE_EFFECT        => 3,
      :OVERLAY_TYPE           => 1,
      :OVERLAY_FILE           => nil,
      :START_SE               => nil,
      :CRY_DISTORTION         => 0,
      :SKIP_SPLASH            => true,
      :SHOW_IN_DEBUG          => true
    },

    :showcase_default => {
      :BACKGROUND_TYPE        => 0,
      :BACKGROUND_FILE        => "Backgrounds/clouded",
      :INTRO_ANIMATION        => 7,
      :TITLE_BGM              => "title_origin",
      :LOGO_FILE              => "logo",
      :LOGO_POS               => [nil, nil],
      :LOGO2_FILE             => "logo2",
      :LOGO2_OFFSET_Y         => 140,
      :LOGO_GLOW              => true,
      :LOGO_SHINE             => true,
      :LOGO_SPARKLE           => false,
      :PARTICLE_EFFECT        => 3,
      :OVERLAY_TYPE           => 0,
      :OVERLAY_FILE           => nil,
      :START_POS              => [nil, nil],
      :START_SE               => nil,
      :START_SE_VOLUME        => 100,
      :START_SE_PITCH         => 100,
      :START_SE_DELAY         => 0,
      :CRY_DISTORTION         => 0,
      :CRY_DISTORTION_POWER   => 5,
      :SHOW_IN_DEBUG          => true,
      :SKIP_SPLASH            => true,
      :SPLASH_IMAGES          => ["splash1", "splash2", "splash3"],
      :SPLASH_FADE_TICKS      => 10,
      :SPLASH_DURATION        => 2,
      :BACKGROUND_FOLDER      => "AnimBackground",
      :BACKGROUND_FRAME_COUNT => 384,
      :BACKGROUND_FRAME_DELAY => 2
    },

    :showcase_scrolling_fog => {
      :BACKGROUND_TYPE  => 1,
      :BACKGROUND_FILE  => "Backgrounds/scrolling",
      :INTRO_ANIMATION  => 1,
      :TITLE_BGM        => "title_rse",
      :LOGO_FILE        => "logo",
      :LOGO2_FILE       => "logo2",
      :LOGO2_OFFSET_Y   => 140,
      :LOGO_GLOW        => false,
      :LOGO_SHINE       => false,
      :LOGO_SPARKLE     => false,
      :PARTICLE_EFFECT  => 1,
      :OVERLAY_TYPE     => 1,
      :OVERLAY_FILE     => "Overlays/waves1",
      :START_SE         => nil,
      :CRY_DISTORTION   => 0,
      :SKIP_SPLASH      => true,
      :SHOW_IN_DEBUG    => true
    },

    :showcase_digital_glitch => {
      :BACKGROUND_TYPE      => 4,
      :BACKGROUND_FILE      => "Backgrounds/digital",
      :INTRO_ANIMATION      => 3,
      :TITLE_BGM            => "title_bw",
      :LOGO_GLOW            => true,
      :LOGO_SHINE           => false,
      :LOGO_SPARKLE         => true,
      :PARTICLE_EFFECT      => 0,
      :OVERLAY_TYPE         => 3,
      :OVERLAY_FILE         => "Overlays/static003",
      :START_SE             => nil,
      :START_SE_DELAY       => 0,
      :CRY_DISTORTION       => 0,
      :SKIP_SPLASH          => true,
      :SHOW_IN_DEBUG        => true
    },

    :showcase_light_rays => {
      :BACKGROUND_TYPE  => 0,
      :BACKGROUND_FILE  => "Backgrounds/radiant",
      :INTRO_ANIMATION  => 2,
      :TITLE_BGM        => "title_xy",
      :LOGO_GLOW        => true,
      :LOGO_SHINE       => true,
      :LOGO_SPARKLE     => false,
      :PARTICLE_EFFECT  => 5,
      :OVERLAY_TYPE     => 0,
      :OVERLAY_FILE     => nil,
      :START_SE         => nil,
      :CRY_DISTORTION   => 0,
      :SKIP_SPLASH      => true,
      :SHOW_IN_DEBUG    => true
    },

    :showcase_animated_frames => {
      :BACKGROUND_TYPE        => 5,
      :BACKGROUND_FILE        => nil,
      :BACKGROUND_FOLDER      => "AnimBackground",
      :BACKGROUND_FRAME_COUNT => 384,
      :BACKGROUND_FRAME_DELAY => 2,
      :INTRO_ANIMATION        => 0,
      :TITLE_BGM              => "title_sm",
      :LOGO_GLOW              => true,
      :LOGO_SHINE             => false,
      :LOGO_SPARKLE           => true,
      :PARTICLE_EFFECT        => 4,
      :OVERLAY_TYPE           => 0,
      :OVERLAY_FILE           => nil,
      :START_SE               => nil,
      :CRY_DISTORTION         => 0,
      :SKIP_SPLASH            => true,
      :SHOW_IN_DEBUG          => true
    }
  }

  def self._preset_value(preset_hash, key, default)
    return preset_hash[key] if preset_hash && preset_hash.has_key?(key)
    return default
  end

  _preset = PRESETS[PRESET] || {}

  #-----------------------------------------------------------------------------
  # BACKGROUND TYPE - Choose how your background displays
  #-----------------------------------------------------------------------------
  #   0 = Static image (bg0.png)
  #   1 = Horizontal scroll (bg1.png tiles left-right)
  #   2 = Vertical scroll (bg2.png tiles up-down)
  #   3 = Spritesheet animation (bg3.png - frames side by side)
  #   4 = Color cycling effect (bg4.png with shifting hue)
  #   5 = Frame animation (numbered PNGs in a folder for using gifs or something)
  #-----------------------------------------------------------------------------
  BACKGROUND_TYPE = _preset_value(_preset, :BACKGROUND_TYPE, 0)
  
  #-----------------------------------------------------------------------------
  # BACKGROUND FILE - Custom filename (without extension)
  # Leave as nil to use default naming (bg0.png, bg1.png, etc.)
  # Example: "mybg" loads Graphics/MODTS/mybg.png
  #-----------------------------------------------------------------------------
  BACKGROUND_FILE = _preset_value(_preset, :BACKGROUND_FILE, nil)
  
  #=============================================================================
  #  FRAME ANIMATION SETTINGS (only used when BACKGROUND_TYPE = 5)
  #=============================================================================
  #  Convert a or mp4 etc to numbered frames and place them in a subfolder.
  #  Name them: 000.png, 001.png, 002.png, etc.
  #  
  #  Example folder structure:
  #    Graphics/MODTS/Backgrounds/000.png
  #    Graphics/MODTS/Backgrounds/001.png
  #    Graphics/MODTS/Backgrounds/002.png
  #    etc
  #=============================================================================
  
  #-----------------------------------------------------------------------------
  # Subfolder name inside Graphics/MODTS/ containing your frames
  #-----------------------------------------------------------------------------
  BACKGROUND_FOLDER = _preset_value(_preset, :BACKGROUND_FOLDER, "AnimBackground")
  
  #-----------------------------------------------------------------------------
  # Total number of frames in your animation
  #-----------------------------------------------------------------------------
  BACKGROUND_FRAME_COUNT = _preset_value(_preset, :BACKGROUND_FRAME_COUNT, 384)
  
  #-----------------------------------------------------------------------------
  # Delay between frames (higher = slower animation)
  # 1 = 60fps, 2 = 30fps, 3 = 20fps, 4 = 15fps, 6 = 10fps
  #-----------------------------------------------------------------------------
  BACKGROUND_FRAME_DELAY = _preset_value(_preset, :BACKGROUND_FRAME_DELAY, 2)
  
  #=============================================================================
  #  INTRO ANIMATION
  #=============================================================================
  
  #-----------------------------------------------------------------------------
  # Intro animation style - how elements appear when title loads
  #-----------------------------------------------------------------------------
  #   0 = Simple fade in (all at once)
  #   1 = Logo slides down from top
  #   2 = Logo zooms in from small
  #   3 = White flash that fades out
  #   4 = Logo slides in from left
  #   5 = Elements fade in one by one
  #   6 = Quick fade with particle burst
  #   7 = Smooth layered fade (BG -> effects -> logo)
  #-----------------------------------------------------------------------------
  INTRO_ANIMATION = _preset_value(_preset, :INTRO_ANIMATION, 0)
  
  #=============================================================================
  #  MUSIC
  #=============================================================================
  
  #-----------------------------------------------------------------------------
  # BGM filename (in Audio/BGM/, without extension)
  # Set to nil to use game's default title music
  #-----------------------------------------------------------------------------
  TITLE_BGM = _preset_value(_preset, :TITLE_BGM, nil)
  
  #=============================================================================
  #  LOGO SETTINGS
  #=============================================================================
  
  #-----------------------------------------------------------------------------
  # Main logo file (in Graphics/MODTS/, without extension)
  #-----------------------------------------------------------------------------
  LOGO_FILE = _preset_value(_preset, :LOGO_FILE, "logo")
  
  #-----------------------------------------------------------------------------
  # Logo position [x, y] in pixels
  # Use nil for default (x = centered, y = 35% from top)
  #-----------------------------------------------------------------------------
  LOGO_POS = _preset_value(_preset, :LOGO_POS, [nil, nil])
  
  #-----------------------------------------------------------------------------
  # Secondary logo file (displayed below main logo)
  # Set to nil to disable, or specify filename like "logo2"
  #-----------------------------------------------------------------------------
  LOGO2_FILE = _preset_value(_preset, :LOGO2_FILE, "logo2")
  
  #-----------------------------------------------------------------------------
  # Secondary logo vertical offset (pixels below the main logo)
  # Positive = lower, Negative = higher
  #-----------------------------------------------------------------------------
  LOGO2_OFFSET_Y = _preset_value(_preset, :LOGO2_OFFSET_Y, 130)
  
  #=============================================================================
  #  LOGO EFFECTS
  #=============================================================================
  
  #-----------------------------------------------------------------------------
  # Glow effect - soft glow behind logo (needs logo_glow.png)
  #-----------------------------------------------------------------------------
  LOGO_GLOW = _preset_value(_preset, :LOGO_GLOW, false)
  
  #-----------------------------------------------------------------------------
  # Shine effect - light sweep across logo (needs logo_shine.png)
  #-----------------------------------------------------------------------------
  LOGO_SHINE = _preset_value(_preset, :LOGO_SHINE, false)
  
  #-----------------------------------------------------------------------------
  # Sparkle effect - random sparkles on logo (needs sparkle.png)
  #-----------------------------------------------------------------------------
  LOGO_SPARKLE = _preset_value(_preset, :LOGO_SPARKLE, false)
  
  #=============================================================================
  #  PARTICLE EFFECTS
  #=============================================================================
  
  #-----------------------------------------------------------------------------
  # Particle effect type:
  #   0 = None
  #   1 = Rising particles (embers, dust rising)
  #   2 = Falling particles (rain, snow, ash)
  #   3 = Floating particles (spores, fireflies)
  #   4 = Sparkle bursts (random twinkles)
  #   5 = Light rays (volumetric beams from center)
  #-----------------------------------------------------------------------------
  PARTICLE_EFFECT = _preset_value(_preset, :PARTICLE_EFFECT, 0)
  
  #=============================================================================
  #  OVERLAY
  #=============================================================================
  
  #-----------------------------------------------------------------------------
  # Overlay type (layer on top of background):
  #   0 = None
  #   1 = Horizontal scroll (fog, clouds)
  #   2 = Vertical scroll (rain streaks)
  #   3 = Pulsing opacity (vignette, scanlines)
  #-----------------------------------------------------------------------------
  OVERLAY_TYPE = _preset_value(_preset, :OVERLAY_TYPE, 0)
  
  #-----------------------------------------------------------------------------
  # Overlay file (in Graphics/MODTS/, without extension)
  # Set to nil for default (overlay1.png, overlay2.png, etc.)
  #-----------------------------------------------------------------------------
  OVERLAY_FILE = _preset_value(_preset, :OVERLAY_FILE, nil)
  
  #=============================================================================
  #  "PRESS START" TEXT
  #=============================================================================
  
  #-----------------------------------------------------------------------------
  # "Press Start" position [x, y] in pixels
  # Use nil for default (x = centered, y = 85% from top)
  #-----------------------------------------------------------------------------
  START_POS = _preset_value(_preset, :START_POS, [nil, nil])
  
  #=============================================================================
  #  POKEMON CRY
  #=============================================================================
  #  START SOUND EFFECT
  #  Plays when player presses Start. Set to nil to disable.
  #=============================================================================
  
  #-----------------------------------------------------------------------------
  # Sound effect file (in Audio/SE/, without extension)
  # Example: "start_sound" plays Audio/SE/start_sound.ogg
  # Set to nil for no sound
  #-----------------------------------------------------------------------------
  START_SE = _preset_value(_preset, :START_SE, nil)
  
  #-----------------------------------------------------------------------------
  # Sound effect volume (0-100)
  #-----------------------------------------------------------------------------
  START_SE_VOLUME = _preset_value(_preset, :START_SE_VOLUME, 100)
  
  #-----------------------------------------------------------------------------
  # Sound effect pitch (50-150, 100 = normal)
  #-----------------------------------------------------------------------------
  START_SE_PITCH = _preset_value(_preset, :START_SE_PITCH, 100)
  
  #-----------------------------------------------------------------------------
  # Delay after sound plays before transitioning (in seconds)
  # Allows the sound to play before screen changes
  #-----------------------------------------------------------------------------
  START_SE_DELAY = _preset_value(_preset, :START_SE_DELAY, 0)
  
  #-----------------------------------------------------------------------------
  # Screen distortion effect during cry
  # Options:
  #   0 = None (no distortion)
  #   1 = Screen shake (camera shake effect)
  #   2 = Wave distortion (smooth screen warping)
  #   3 = Flash pulse (brightness pulsing)
  #   4 = Color shift (RGB color distortion)
  #   5 = Glitch (datamoshing effect)
  #-----------------------------------------------------------------------------
  CRY_DISTORTION = _preset_value(_preset, :CRY_DISTORTION, 0)
  
  #-----------------------------------------------------------------------------
  # Distortion intensity (1-10, higher = stronger effect)
  # Recommended: 3-5 for subtle, 6-8 for medium, 9-10 for intense
  #-----------------------------------------------------------------------------
  CRY_DISTORTION_POWER = _preset_value(_preset, :CRY_DISTORTION_POWER, 5)
  
  #=============================================================================
  #  DEBUG OPTIONS
  #=============================================================================
  
  #-----------------------------------------------------------------------------
  # Show custom title screen even in debug mode?
  #-----------------------------------------------------------------------------
  SHOW_IN_DEBUG = _preset_value(_preset, :SHOW_IN_DEBUG, false)
  
  #=============================================================================
  #  SPLASH SCREENS (images before title screen)
  #=============================================================================
  
  #-----------------------------------------------------------------------------
  # Skip splash screens entirely?
  # Set to false if you want to customize them below
  #-----------------------------------------------------------------------------
  SKIP_SPLASH = _preset_value(_preset, :SKIP_SPLASH, false)
  
  #-----------------------------------------------------------------------------
  # Splash screen images (in Graphics/MODTS/, without extension)
  # Images will fade in, hold, then fade out in sequence
  # Set to empty array [] to skip, or add your custom images
  #-----------------------------------------------------------------------------
  SPLASH_IMAGES = _preset_value(_preset, :SPLASH_IMAGES, ["splash1", "splash2", "splash3"])
  
  #-----------------------------------------------------------------------------
  # Fade speed (higher = slower fade, lower = faster)
  # Default is 10
  #-----------------------------------------------------------------------------
  SPLASH_FADE_TICKS = _preset_value(_preset, :SPLASH_FADE_TICKS, 10)
  
  #-----------------------------------------------------------------------------
  # How long each splash image stays on screen (in seconds)
  #-----------------------------------------------------------------------------
  SPLASH_DURATION = _preset_value(_preset, :SPLASH_DURATION, 2)
  
  #=============================================================================
  # AUTO-GENERATED MODIFIERS (don't edit below - builds from settings above)
  #=============================================================================
  def self.build_modifiers
    mods = []
    
    # Background
    if BACKGROUND_FILE
      mods << "BACKGROUND:#{BACKGROUND_FILE}"
    else
      mods << "background#{BACKGROUND_TYPE > 0 ? BACKGROUND_TYPE : ''}"
    end
    
    # Particle effect
    mods << "effect#{PARTICLE_EFFECT}" if PARTICLE_EFFECT > 0
    
    # Logo effects
    mods << "logo: glow" if LOGO_GLOW
    mods << "logo: shine" if LOGO_SHINE
    mods << "logo:sparkle" if LOGO_SPARKLE
    
    # Overlay
    if OVERLAY_TYPE > 0
      if OVERLAY_FILE
        mods << "OVERLAY:#{OVERLAY_FILE}"
      else
        mods << "overlay#{OVERLAY_TYPE}"
      end
    end
    
    # Intro animation
    mods << "intro:#{INTRO_ANIMATION}" if INTRO_ANIMATION > 0
    
    # Positions
    mods << "LOGOX:#{LOGO_POS[0]}" if LOGO_POS[0]
    mods << "LOGOY:#{LOGO_POS[1]}" if LOGO_POS[1]
    
    # BGM
    mods << "BGM:#{TITLE_BGM}" if TITLE_BGM
    
    mods
  end
  
  MODIFIERS = build_modifiers
  
end
