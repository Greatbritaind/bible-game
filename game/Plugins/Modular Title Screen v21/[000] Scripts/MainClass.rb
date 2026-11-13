#===============================================================================
#  Modular Title Screen - Main Class
#  Adapted for Pokemon Essentials v21.1
#===============================================================================
class ModularTitleScreen
  #-----------------------------------------------------------------------------
  # Initialize the title screen
  #-----------------------------------------------------------------------------
  def initialize
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    @intro = nil
    @currentFrame = 0
    @totalFrames = nil
    @mods = ModularTitle::MODIFIERS
    
    bg = "BG0"
    backdrop = "nil"
    bg_selected = false
    i = 0; o = 0; m = 0
    
    @mods.each do |mod|
      arg = mod.to_s. upcase
      x = "nil"; y = "nil"; z = "nil"; zoom = "nil"; file = "nil"; speed = "nil"
      
      #-------------------------------------------------------------------------
      # Background setup
      #-------------------------------------------------------------------------
      if arg. include?("BACKGROUND:")
        next if bg_selected
        cmd = arg.split("_").compact
        backdrop = "\"" + cmd[0]. gsub("BACKGROUND:", "") + "\""
        bg_selected = true
      elsif arg.include?("BACKGROUND")
        next if bg_selected
        cmd = arg.split("_").compact
        s = "BG" + cmd[0].gsub("BACKGROUND", "")
        if eval("defined?(MTS_Element_#{s})")
          bg = s
          bg_selected = true
        end
      #-------------------------------------------------------------------------
      # Intro animation setup
      #-------------------------------------------------------------------------
      elsif arg.include?("INTRO:")
        next if !@intro. nil?
        cmd = arg. split("_").compact
        @intro = cmd[0].gsub("INTRO:", "")
      #-------------------------------------------------------------------------
      # Overlay setup
      #-------------------------------------------------------------------------
      elsif arg.include?("OVERLAY:")
        cmd = arg.split("_").compact
        file = cmd[0].gsub("OVERLAY:", "")
        if cmd.length > 1
          cmd[1..-1].each do |c|
            z = c.gsub("Z", "").to_i if c.include?("Z")
          end
        end
        z = nil if z == "nil"
        @sprites["ol#{o}"] = MTS_Element_OLX.new(@viewport, file, z)
        o += 1
      elsif arg.include?("OVERLAY")
        cmd1 = mod.split("_").compact
        cmd2 = cmd1[0].split(":").compact
        s = "OL" + cmd2[0].upcase. gsub("OVERLAY", "")
        f = cmd2.length > 1 ? ("\"" + cmd2[1] + "\"") : "nil"
        if cmd1.length > 1
          cmd1[1..-1]. each do |c|
            cu = c.upcase
            z = cu.gsub("Z", "").to_i if cu.include? ("Z")
            speed = cu.gsub("S", "").to_i if cu.include?("S")
          end
        end
        if eval("defined?(MTS_Element_#{s})")
          @sprites["ol#{o}"] = eval("MTS_Element_#{s}. new(@viewport,#{f},#{z},#{speed})")
          o += 1
        end
      #-------------------------------------------------------------------------
      # Effect setup
      #-------------------------------------------------------------------------
      elsif arg.include?("EFFECT")
        cmd = arg.split("_").compact
        s = "FX" + cmd[0].gsub("EFFECT", "")
        if cmd.length > 1
          cmd[1..-1].each do |c|
            x = c.gsub("X", "") if c.include?("X")
            y = c.gsub("Y", "") if c.include?("Y")
            z = c.gsub("Z", "") if c.include?("Z")
          end
        end
        if eval("defined?(MTS_Element_#{s})")
          @sprites["fx#{i}"] = eval("MTS_Element_#{s}.new(@viewport,#{x},#{y},#{z})")
          i += 1
        end
      #-------------------------------------------------------------------------
      # Misc element setup
      #-------------------------------------------------------------------------
      elsif arg.include?("MISC")
        cmd = mod.split("_").compact
        mfx = cmd[0].split(":").compact
        s = "MX" + mfx[0].upcase. gsub("MISC", "")
        file = "\"" + mfx[1] + "\"" if mfx.length > 1
        if cmd.length > 1
          cmd[1..-1].each do |c|
            cu = c.upcase
            x = cu.gsub("X", "") if cu.include?("X")
            y = cu.gsub("Y", "") if cu.include?("Y")
            z = cu.gsub("Z", "") if cu.include?("Z")
            zoom = cu.gsub("S", "") if cu.include?("S")
          end
        end
        if eval("defined?(MTS_Element_#{s})")
          @sprites["mx#{m}"] = eval("MTS_Element_#{s}.new(@viewport,#{x},#{y},#{z},#{zoom},#{file})")
          m += 1
        end
      end
    end
    
    # Create background
    @sprites["bg"] = eval("MTS_Element_#{bg}.new(@viewport,#{backdrop})")
    
    # Create logo
    @sprites["logo"] = MTS_Element_Logo.new(@viewport)
    @sprites["logo"].position
    
    # Create "Press Start" text
    @sprites["start"] = Sprite.new(@viewport)
    @sprites["start"].bitmap = AnimatedBitmap.new("Graphics/MODTS/start").bitmap
    @sprites["start"].center! 
    @sprites["start"].x = @viewport.rect.width / 2
    @sprites["start"].x = ModularTitle::START_POS[0] if ModularTitle::START_POS[0]. is_a?(Numeric)
    @sprites["start"].y = @viewport.rect. height * 0.85
    @sprites["start"].y = ModularTitle::START_POS[1] if ModularTitle::START_POS[1]. is_a?(Numeric)
    @sprites["start"].z = 999
    @sprites["start"].visible = false
    @fade = 8
  end
  
  #-----------------------------------------------------------------------------
  # Play intro animation
  #-----------------------------------------------------------------------------
  def intro
    if eval("defined?(MTS_INTRO_ANIM#{@intro})")
      intro_anim = eval("MTS_INTRO_ANIM#{@intro}. new(@viewport,@sprites)")
    else
      intro_anim = MTS_INTRO_ANIM. new(@viewport, @sprites)
    end
    @currentFrame = intro_anim.currentFrame
    @sprites["start"].visible = true
  end
  
  #-----------------------------------------------------------------------------
  # Update all elements
  #-----------------------------------------------------------------------------
  def updateElements
    @sprites. each_key do |key|
      @sprites[key].update if @sprites[key].respond_to?(:update)
    end
    @sprites["start"].opacity -= @fade
    @fade *= -1 if @sprites["start"].opacity <= 0 || @sprites["start"].opacity >= 255
  end
  
  #-----------------------------------------------------------------------------
  # Main update
  #-----------------------------------------------------------------------------
  def update
    @currentFrame += 1
    updateElements
    if ! @totalFrames.nil? && @totalFrames >= 0 && @currentFrame >= @totalFrames
      restart
    end
  end
  
  #-----------------------------------------------------------------------------
  # Dispose all elements
  #-----------------------------------------------------------------------------
  def dispose
    @sprites.each_key do |key|
      @sprites[key].dispose
    end
    @viewport.dispose
  end
  
  #-----------------------------------------------------------------------------
  # Play BGM
  #-----------------------------------------------------------------------------
  def playBGM
    bgm_name = nil
    @mods.each do |mod|
      arg = mod.to_s.upcase
      next if !arg.include?("BGM:")
      # Preserve original casing of the filename after "BGM:"
      bgm_name = mod.to_s.gsub(/.*BGM:/i, "")
      break
    end
    bgm_name = $data_system.title_bgm.name if bgm_name.nil?

    # Resolve to an audio file (prevents crashes if the file doesn't exist)
    resolved = nil
    begin
      resolved = pbResolveAudioFile(bgm_name)
    rescue
      resolved = nil
    end

    bgm_to_play = resolved
    if bgm_to_play.nil? || bgm_to_play.name.nil? || bgm_to_play.name == ""
      bgm_to_play = $data_system.title_bgm
    end

    # Try to get play time for looping
    begin
      @totalFrames = (getPlayTime("Audio/BGM/" + bgm_to_play.name).floor - 1) * Graphics.frame_rate
    rescue
      @totalFrames = -1
    end

    pbBGMPlay(bgm_to_play)
  end
  
  #-----------------------------------------------------------------------------
  # Restart title screen when BGM ends
  #-----------------------------------------------------------------------------
  def restart
    pbBGMStop(0)
    51.times do
      @viewport.tone.red -= 5
      @viewport.tone.green -= 5
      @viewport. tone.blue -= 5
      updateElements
      Graphics.update
    end
    raise Reset. new
  end
end