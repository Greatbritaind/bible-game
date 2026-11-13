#===============================================================================
#  Modular Title Screen - Scene Intro
#  Adapted for Pokemon Essentials v21.1
#===============================================================================
class Scene_Intro
  #-----------------------------------------------------------------------------
  # Main entry point
  #-----------------------------------------------------------------------------
  def main
    Graphics.transition(0)
    Input.update
    
    # Load start sound effect
    @start_se = ModularTitle::START_SE
    
    @skip = false
    
    # Cycle through intro splash images
    cyclePics
    
    # Load the modular title screen
    @screen = ModularTitleScreen.new
    
    # Play title screen BGM
    @screen.playBGM
    
    # Play intro animation
    @screen.intro
    
    # Main update loop
    update
    
    Graphics.freeze
  end
  
  #-----------------------------------------------------------------------------
  # Main update loop
  #-----------------------------------------------------------------------------
  def update
    ret = 0
    loop do
      @screen.update
      Graphics.update
      Input.update
      
      # Check for delete save combo (Down + Back + Ctrl)
      if Input.press?(Input::DOWN) && Input.press?(Input::BACK) && Input.press?(Input::CTRL)
        ret = 1
        break
      end
      
      # Check for start button
      if Input.trigger?(Input::USE) || Input.trigger?(Input::ACTION)
        ret = 2
        break
      end
    end
    
    case ret
    when 1
      closeTitleDelete
    when 2
      closeTitle
    end
  end
  
  #-----------------------------------------------------------------------------
  # Close title screen normally
  #-----------------------------------------------------------------------------
  def closeTitle
    # Play start sound effect
    if @start_se
      pbSEPlay(@start_se, ModularTitle::START_SE_VOLUME, ModularTitle::START_SE_PITCH)
    end
    # Wait for sound to play while keeping animations running
    if @start_se && ModularTitle::START_SE_DELAY > 0
      delay_frames = (Graphics.frame_rate * ModularTitle::START_SE_DELAY).to_i
      distortion_type = ModularTitle::CRY_DISTORTION
      power = ModularTitle::CRY_DISTORTION_POWER
      
      delay_frames.times do |i|
        # Apply distortion effect
        apply_cry_distortion(@screen, i, delay_frames, distortion_type, power)
        
        @screen.update  # Keep title screen animations running
        Graphics.update
        Input.update
      end
      
      # Reset distortion
      reset_cry_distortion(@screen)
    end
    # Fade out BGM
    pbBGMStop(1.0)
    # Dispose title screen
    disposeTitle
    # Go to load screen
    sscene = PokemonLoad_Scene.new
    sscreen = PokemonLoadScreen.new(sscene)
    sscreen.pbStartLoadScreen
  end
  
  #-----------------------------------------------------------------------------
  # Apply cry distortion effects
  #-----------------------------------------------------------------------------
  def apply_cry_distortion(screen, frame, total_frames, type, power)
    return if type == 0 || !screen.instance_variable_get(:@viewport)
    
    viewport = screen.instance_variable_get(:@viewport)
    progress = frame.to_f / total_frames
    intensity = Math.sin(progress * Math::PI) * power  # Peak in middle, fade at start/end
    
    case type
    when 1  # Screen shake
      offset_x = (rand * intensity * 2 - intensity).to_i
      offset_y = (rand * intensity * 2 - intensity).to_i
      viewport.rect.x = offset_x
      viewport.rect.y = offset_y
      
    when 2  # Wave distortion (simulated with smooth shake pattern)
      wave = Math.sin(frame * 0.5) * intensity
      viewport.rect.x = wave.to_i
      viewport.rect.y = (Math.cos(frame * 0.3) * intensity * 0.5).to_i
      
    when 3  # Flash pulse
      flash_val = (Math.sin(frame * 0.8) * intensity * 5).to_i
      viewport.tone.red = flash_val
      viewport.tone.green = flash_val
      viewport.tone.blue = flash_val
      
    when 4  # Color shift
      r = (Math.sin(frame * 0.5) * intensity * 8).to_i
      g = (Math.sin(frame * 0.5 + 2) * intensity * 8).to_i
      b = (Math.sin(frame * 0.5 + 4) * intensity * 8).to_i
      viewport.tone.red = r
      viewport.tone.green = g
      viewport.tone.blue = b
      
    when 5  # Datamosh/Glitch - compression, ghosting, broken look
      sprites = screen.instance_variable_get(:@sprites)
      glitch_chance = rand(10)
      
      if glitch_chance < 3  # 30% - Horizontal compression (squash)
        compress = 1.0 - (intensity * 0.03)
        sprites.each_value do |spr|
          next unless spr.respond_to?(:zoom_x=)
          spr.zoom_x = compress + rand * 0.1
        end
        viewport.rect.x = (intensity * 2).to_i * (rand(2) == 0 ? 1 : -1)
        
      elsif glitch_chance < 5  # 20% - Vertical stretch (elongate)
        stretch = 1.0 + (intensity * 0.04)
        sprites.each_value do |spr|
          next unless spr.respond_to?(:zoom_y=)
          spr.zoom_y = stretch
          spr.zoom_x = 1.0 - (intensity * 0.02) if spr.respond_to?(:zoom_x=)
        end
        
      elsif glitch_chance < 7  # 20% - Ghost/fade (semi-transparent broken frames)
        ghost_opacity = 255 - (intensity * 15).to_i
        sprites.each_value do |spr|
          next unless spr.respond_to?(:opacity=)
          spr.opacity = ghost_opacity + rand(30)
        end
        viewport.tone.gray = (intensity * 8).to_i  # Desaturate
        
      elsif glitch_chance < 9  # 20% - Double vision offset
        offset = (intensity * 3).to_i
        sprites.each_value do |spr|
          next unless spr.respond_to?(:x) && spr.respond_to?(:x=) && spr.x
          spr.x = spr.x + offset * (rand(2) == 0 ? 1 : -1) if rand(2) == 0
        end
        viewport.tone.gray = (intensity * 5).to_i
        
      else  # 10% - Full corruption flash
        viewport.color = Color.new(255, 255, 255, (intensity * 8).to_i)
        sprites.each_value do |spr|
          if spr.respond_to?(:zoom_x=)
            spr.zoom_x = 0.9 + rand * 0.2
            spr.zoom_y = 0.9 + rand * 0.2 if spr.respond_to?(:zoom_y=)
          end
        end
      end
    end
  end
  
  #-----------------------------------------------------------------------------
  # Reset distortion effects
  #-----------------------------------------------------------------------------
  def reset_cry_distortion(screen)
    return if !screen.instance_variable_get(:@viewport)
    viewport = screen.instance_variable_get(:@viewport)
    viewport.rect.x = 0
    viewport.rect.y = 0
    viewport.tone.red = 0
    viewport.tone.green = 0
    viewport.tone.blue = 0
    viewport.tone.gray = 0
    viewport.color = Color.new(0, 0, 0, 0)
    
    # Reset sprite properties
    sprites = screen.instance_variable_get(:@sprites)
    return unless sprites
    sprites.each_value do |spr|
      spr.zoom_x = 1.0 if spr.respond_to?(:zoom_x=)
      spr.zoom_y = 1.0 if spr.respond_to?(:zoom_y=)
      spr.opacity = 255 if spr.respond_to?(:opacity=)
    end
    # Re-position elements (handled by their update methods)
  end
  
  #-----------------------------------------------------------------------------
  # Close title screen for save deletion
  #-----------------------------------------------------------------------------
  def closeTitleDelete
    pbBGMStop(1.0)
    disposeTitle
    sscene = PokemonLoad_Scene.new
    sscreen = PokemonLoadScreen.new(sscene)
    sscreen.pbStartDeleteScreen
  end
  
  #-----------------------------------------------------------------------------
  # Cycle splash images before title
  #-----------------------------------------------------------------------------
  def cyclePics
    # Skip if configured
    return if ModularTitle::SKIP_SPLASH
    
    # Use custom config settings or fallback to Essentials defaults
    pics = ModularTitle::SPLASH_IMAGES || []
    return if pics.empty?
    
    fade_ticks = ModularTitle::SPLASH_FADE_TICKS || 10
    seconds_per = ModularTitle::SPLASH_DURATION || 2
    
    frames = (Graphics.frame_rate * (fade_ticks / 20.0)).ceil
    sprite = Sprite.new
    sprite.opacity = 0
    
    pics.each do |pic|
      sprite.bitmap = AnimatedBitmap.new("Graphics/MODTS/#{pic}").bitmap
      
      # Fade in
      frames. times do
        sprite.opacity += 255.0 / frames
        pbWait(0.025)
      end
      
      # Hold
      pbWait(seconds_per)
      
      # Fade out
      frames.times do
        sprite.opacity -= 255.0 / frames
        pbWait(0.025)
      end
    end
    
    sprite.dispose
  end
  
  #-----------------------------------------------------------------------------
  # Dispose title screen
  #-----------------------------------------------------------------------------
  def disposeTitle
    @screen.dispose
  end
  
  #-----------------------------------------------------------------------------
  # Skippable wait
  #-----------------------------------------------------------------------------
  def wait(seconds = 0.05)
    return false if @skip
    start_time = System.uptime
    while System.uptime - start_time < seconds
      Graphics.update
      Input.update
      if Input.trigger?(Input::USE)
        @skip = true
        return false
      end
    end
    true
  end
end

#===============================================================================
#  Sprite compatibility extension
#===============================================================================
class Sprite
  attr_accessor :id
end

#===============================================================================
#  Title call override
#===============================================================================
def pbCallTitle
  return Scene_DebugIntro.new if $DEBUG && ! ModularTitle::SHOW_IN_DEBUG
  return Scene_Intro.new
end