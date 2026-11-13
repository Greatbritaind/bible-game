#===============================================================================
#  Intro Animations for Modular Title Screen
#===============================================================================

#-------------------------------------------------------------------------------
# Base intro animation (simple fade in)
#-------------------------------------------------------------------------------
class MTS_INTRO_ANIM
  attr_reader :currentFrame
  
  def initialize(viewport, sprites)
    @viewport = viewport
    @sprites = sprites
    @currentFrame = 0
    
    playAnimation
  end
  
  def playAnimation
    # Fade in all elements
    30.times do |i|
      @sprites.each_key do |key|
        next if key == "start"
        @sprites[key].opacity = (i * 255.0 / 30).to_i if @sprites[key].respond_to?(:opacity=)
      end
      # Update background animation
      @sprites["bg"].update if @sprites["bg"] && @sprites["bg"].respond_to?(:update)
      Graphics.update
      @currentFrame += 1
    end
  end
end

#-------------------------------------------------------------------------------
# Intro 1: Slide in from top
#-------------------------------------------------------------------------------
class MTS_INTRO_ANIM1 < MTS_INTRO_ANIM
  def playAnimation
    # Set initial positions
    @sprites["logo"].y = -100 if @sprites["logo"]
    @sprites["logo"].opacity = 255 if @sprites["logo"]
    
    targetY = Graphics.height * 0.35
    
    # Parse for custom logo Y
    ModularTitle::MODIFIERS.each do |mod|
      if mod.to_s. upcase. include?("LOGOY:")
        targetY = mod.to_s. upcase.gsub("LOGOY:", "").to_i
        break
      end
    end
    
    # Fade in background
    20.times do |i|
      if @sprites["bg"] && @sprites["bg"].respond_to?(:opacity=)
        @sprites["bg"]. opacity = (i * 255.0 / 20).to_i
      end
      @sprites. each_key do |key|
        next if ["logo", "start", "bg"].include?(key)
        if @sprites[key]. respond_to?(:opacity=)
          @sprites[key].opacity = (i * 255.0 / 20).to_i
        end
      end
      # Update background animation
      @sprites["bg"].update if @sprites["bg"] && @sprites["bg"].respond_to?(:update)
      Graphics.update
      @currentFrame += 1
    end
    
    # Slide logo down
    startY = -100
    30.times do |i|
      progress = i / 29.0
      # Ease out
      eased = 1 - (1 - progress) ** 3
      @sprites["logo"].y = startY + (targetY - startY) * eased if @sprites["logo"]
      # Update background animation
      @sprites["bg"].update if @sprites["bg"] && @sprites["bg"].respond_to?(:update)
      Graphics.update
      @currentFrame += 1
    end
  end
end

#-------------------------------------------------------------------------------
# Intro 2: Zoom in
#-------------------------------------------------------------------------------
class MTS_INTRO_ANIM2 < MTS_INTRO_ANIM
  def playAnimation
    # Set initial state
    if @sprites["logo"]
      @sprites["logo"].opacity = 255
      @sprites["logo"].zoom_x = 0.1 if @sprites["logo"].respond_to?(:zoom_x=)
      @sprites["logo"].zoom_y = 0.1 if @sprites["logo"].respond_to?(:zoom_y=)
    end
    
    # Fade in background
    15.times do |i|
      if @sprites["bg"] && @sprites["bg"].respond_to?(:opacity=)
        @sprites["bg"].opacity = (i * 255.0 / 15).to_i
      end
      @sprites.each_key do |key|
        next if ["logo", "start", "bg"].include?(key)
        if @sprites[key].respond_to?(:opacity=)
          @sprites[key].opacity = (i * 255.0 / 15).to_i
        end
      end
      # Update background animation
      @sprites["bg"].update if @sprites["bg"] && @sprites["bg"].respond_to?(:update)
      Graphics.update
      @currentFrame += 1
    end
    
    # Zoom in logo
    40.times do |i|
      progress = i / 39.0
      # Ease out elastic
      eased = 1 - (1 - progress) ** 2
      if @sprites["logo"]
        zoom = 0.1 + 0.9 * eased
        @sprites["logo"].zoom_x = zoom if @sprites["logo"].respond_to?(:zoom_x=)
        @sprites["logo"].zoom_y = zoom if @sprites["logo"].respond_to?(:zoom_y=)
      end
      # Update background animation
      @sprites["bg"].update if @sprites["bg"] && @sprites["bg"].respond_to?(:update)
      Graphics.update
      @currentFrame += 1
    end
  end
end

#-------------------------------------------------------------------------------
# Intro 3: Fade with flash
#-------------------------------------------------------------------------------
class MTS_INTRO_ANIM3 < MTS_INTRO_ANIM
  def playAnimation
    # Start with white flash
    @viewport.tone = Tone.new(255, 255, 255)
    
    # Show all elements instantly
    @sprites.each_key do |key|
      next if key == "start"
      @sprites[key].opacity = 255 if @sprites[key].respond_to?(:opacity=)
    end
    
    # Fade out flash
    30.times do |i|
      val = 255 - (i * 255.0 / 30)
      @viewport.tone = Tone.new(val, val, val)
      # Update background animation
      @sprites["bg"].update if @sprites["bg"] && @sprites["bg"].respond_to?(:update)
      Graphics.update
      @currentFrame += 1
    end
    
    @viewport.tone = Tone.new(0, 0, 0)
  end
end

#-------------------------------------------------------------------------------
# Intro 4: Slide in from sides
#-------------------------------------------------------------------------------
class MTS_INTRO_ANIM4 < MTS_INTRO_ANIM
  def playAnimation
    centerX = Graphics.width / 2
    
    # Set logo off-screen
    if @sprites["logo"]
      @sprites["logo"].x = -200
      @sprites["logo"].opacity = 255
    end
    
    # Fade in background
    20.times do |i|
      if @sprites["bg"] && @sprites["bg"].respond_to?(:opacity=)
        @sprites["bg"].opacity = (i * 255.0 / 20).to_i
      end
      @sprites.each_key do |key|
        next if ["logo", "start", "bg"].include?(key)
        if @sprites[key].respond_to?(:opacity=)
          @sprites[key].opacity = (i * 255.0 / 20).to_i
        end
      end
      # Update background animation
      @sprites["bg"].update if @sprites["bg"] && @sprites["bg"].respond_to?(:update)
      Graphics.update
      @currentFrame += 1
    end
    
    # Slide logo in
    startX = -200
    targetX = centerX
    
    ModularTitle::MODIFIERS.each do |mod|
      if mod.to_s.upcase. include?("LOGOX:")
        targetX = mod.to_s.upcase.gsub("LOGOX:", "").to_i
        break
      end
    end
    
    35.times do |i|
      progress = i / 34.0
      eased = 1 - (1 - progress) ** 3
      @sprites["logo"].x = startX + (targetX - startX) * eased if @sprites["logo"]
      # Update background animation
      @sprites["bg"].update if @sprites["bg"] && @sprites["bg"].respond_to?(:update)
      Graphics. update
      @currentFrame += 1
    end
  end
end

#-------------------------------------------------------------------------------
# Intro 5: Typewriter/reveal effect
#-------------------------------------------------------------------------------
class MTS_INTRO_ANIM5 < MTS_INTRO_ANIM
  def playAnimation
    # Fade in background first
    30.times do |i|
      if @sprites["bg"] && @sprites["bg"].respond_to?(:opacity=)
        @sprites["bg"].opacity = (i * 255.0 / 30).to_i
      end
      # Update background animation
      @sprites["bg"].update if @sprites["bg"] && @sprites["bg"].respond_to?(:update)
      Graphics.update
      @currentFrame += 1
    end
    
    # Fade in other elements one by one
    keys = @sprites.keys. reject { |k| ["bg", "start"]. include?(k) }
    keys.each do |key|
      15.times do |i|
        if @sprites[key]. respond_to?(:opacity=)
          @sprites[key].opacity = (i * 255.0 / 15).to_i
        end
        # Update background animation
        @sprites["bg"].update if @sprites["bg"] && @sprites["bg"].respond_to?(:update)
        Graphics.update
        @currentFrame += 1
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Intro 6: Particle burst then fade
#-------------------------------------------------------------------------------
class MTS_INTRO_ANIM6 < MTS_INTRO_ANIM
  def playAnimation
    # Quick fade in everything
    20.times do |i|
      @sprites.each_key do |key|
        next if key == "start"
        if @sprites[key].respond_to?(:opacity=)
          @sprites[key].opacity = (i * 255.0 / 20).to_i
        end
      end
      # Update background animation
      @sprites["bg"].update if @sprites["bg"] && @sprites["bg"].respond_to?(:update)
      Graphics.update
      @currentFrame += 1
    end
    
    # Brief bright flash on logo
    if @sprites["logo"]
      10.times do |i|
        # Handled by logo glow effect
        # Update background animation
        @sprites["bg"].update if @sprites["bg"] && @sprites["bg"].respond_to?(:update)
        Graphics.update
        @currentFrame += 1
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Intro 7: Smooth professional fade
#-------------------------------------------------------------------------------
class MTS_INTRO_ANIM7 < MTS_INTRO_ANIM
  def playAnimation
    # Gradual fade with slight delay between layers
    
    # Background first
    40.times do |i|
      if @sprites["bg"] && @sprites["bg"].respond_to?(:opacity=)
        @sprites["bg"].opacity = (i * 255.0 / 40).to_i
      end
      
      # Start fading overlays/effects partway through
      if i > 10
        @sprites. each_key do |key|
          next if ["bg", "logo", "start"].include?(key)
          progress = (i - 10) / 30.0
          if @sprites[key].respond_to?(:opacity=)
            @sprites[key].opacity = (progress * 255).to_i
          end
        end
      end
      
      # Start fading logo near the end
      if i > 20
        progress = (i - 20) / 20.0
        if @sprites["logo"] && @sprites["logo"].respond_to?(:opacity=)
          @sprites["logo"].opacity = (progress * 255).to_i
        end
      end
      
      # Update background animation
      @sprites["bg"].update if @sprites["bg"] && @sprites["bg"].respond_to?(:update)
      Graphics.update
      @currentFrame += 1
    end
  end
end