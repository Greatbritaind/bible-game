#===============================================================================
#  Logo Element for Modular Title Screen
#===============================================================================
class MTS_Element_Logo
  attr_accessor :x, :y, :opacity, :visible
  
  def initialize(viewport)
    @viewport = viewport
    @sprites = {}
    @shine = false
    @sparkle = false
    @glow = false
    @posX = nil
    @posY = nil
    @logo2_offset = 80
    
    # Parse modifiers for logo settings
    ModularTitle::MODIFIERS.each do |mod|
      arg = mod.to_s.upcase
      @shine = true if arg.include?("LOGO: SHINE")
      @sparkle = true if arg.include?("LOGO:SPARKLE")
      @glow = true if arg.include?("LOGO: GLOW")
      @posX = arg.gsub("LOGOX:", "").to_i if arg.include?("LOGOX:")
      @posY = arg.gsub("LOGOY:", "").to_i if arg.include?("LOGOY:")
    end
    
    # Main logo sprite
    logo_file = defined?(ModularTitle::LOGO_FILE) ? ModularTitle::LOGO_FILE : "logo"
    @sprites["logo"] = Sprite.new(@viewport)
    @sprites["logo"].bitmap = AnimatedBitmap.new("Graphics/MODTS/#{logo_file}").bitmap
    @sprites["logo"].center!
    @sprites["logo"].z = 100
    @sprites["logo"].opacity = 0
    
    # Secondary logo (below main logo)
    logo2_file = defined?(ModularTitle::LOGO2_FILE) ? ModularTitle::LOGO2_FILE : nil
    @logo2_offset = defined?(ModularTitle::LOGO2_OFFSET_Y) ? ModularTitle::LOGO2_OFFSET_Y : 80
    if logo2_file && !logo2_file.nil? && pbResolveBitmap("Graphics/MODTS/#{logo2_file}")
      @sprites["logo2"] = Sprite.new(@viewport)
      @sprites["logo2"].bitmap = AnimatedBitmap.new("Graphics/MODTS/#{logo2_file}").bitmap
      @sprites["logo2"].center!
      @sprites["logo2"].z = 99
      @sprites["logo2"].opacity = 0
    end
    
    # Glow effect
    if @glow && pbResolveBitmap("Graphics/MODTS/logo_glow")
      @sprites["glow"] = Sprite.new(@viewport)
      @sprites["glow"].bitmap = AnimatedBitmap.new("Graphics/MODTS/logo_glow").bitmap
      @sprites["glow"].ox = @sprites["glow"].bitmap.width / 2
      @sprites["glow"].oy = @sprites["glow"].bitmap.height / 2
      @sprites["glow"].z = 98
      @sprites["glow"].opacity = 0
      @glowFade = 3
    end
    
    # Shine effect
    if @shine && pbResolveBitmap("Graphics/MODTS/logo_shine")
      @sprites["shine"] = Sprite.new(@viewport)
      @sprites["shine"].bitmap = AnimatedBitmap.new("Graphics/MODTS/logo_shine").bitmap
      @sprites["shine"].center! 
      @sprites["shine"].z = 101
      @sprites["shine"].opacity = 0
      @shineX = -@sprites["shine"].bitmap.width
    end
    
    # Sparkle effect
    if @sparkle
      @sparkleData = []
      8.times do |i|
        @sprites["sparkle#{i}"] = Sprite.new(@viewport)
        if pbResolveBitmap("Graphics/MODTS/sparkle")
          @sprites["sparkle#{i}"].bitmap = AnimatedBitmap.new("Graphics/MODTS/sparkle").bitmap
        end
        if @sprites["sparkle#{i}"].bitmap
          @sprites["sparkle#{i}"].ox = @sprites["sparkle#{i}"].bitmap.width / 2
          @sprites["sparkle#{i}"].oy = @sprites["sparkle#{i}"]. bitmap.height / 2
        end
        @sprites["sparkle#{i}"].z = 102
        @sprites["sparkle#{i}"].opacity = 0
        @sparkleData << { :timer => rand(60), :active => false }
      end
    end
  end
  
  def position
    cx = @posX || @viewport.rect.width / 2
    cy = @posY || @viewport.rect.height * 0.25
    
    # Calculate logo center for positioning glow
    logo_center_y = cy + (@sprites["logo"].bitmap.height / 2) if @sprites["logo"] && @sprites["logo"].bitmap
    
    @sprites.each_key do |key|
      @sprites[key].x = cx
      # Position logo2 below main logo
      if key == "logo2"
        @sprites[key].y = cy + @logo2_offset
      elsif key == "glow"
        # Center glow on logo's vertical center
        @sprites[key].y = logo_center_y || cy
      else
        @sprites[key].y = cy
      end
    end
  end
  
  def x=(val)
    @sprites.each_key { |key| @sprites[key].x = val }
  end
  
  def y=(val)
    @sprites.each_key do |key|
      if key == "logo2"
        @sprites[key].y = val + @logo2_offset
      elsif key == "glow"
        # Center glow on logo's vertical center
        logo_half_height = @sprites["logo"].bitmap ? @sprites["logo"].bitmap.height / 2 : 0
        @sprites[key].y = val + logo_half_height
      else
        @sprites[key].y = val
      end
    end
  end
  
  def opacity=(val)
    @sprites["logo"].opacity = val
    @sprites["logo2"].opacity = val if @sprites["logo2"]
    @sprites["glow"].opacity = val / 2 if @sprites["glow"]
  end
  
  def visible=(val)
    @sprites.each_key { |key| @sprites[key].visible = val }
  end
  
  def update
    # Update glow
    if @sprites["glow"]
      @sprites["glow"].opacity += @glowFade
      @glowFade *= -1 if @sprites["glow"].opacity <= 100 || @sprites["glow"]. opacity >= 200
    end
    
    # Update shine
    if @sprites["shine"]
      @shineX += 4
      @sprites["shine"].x = @sprites["logo"].x + @shineX
      if @shineX > @sprites["logo"].bitmap.width
        @shineX = -@sprites["shine"].bitmap.width
      end
      @sprites["shine"].opacity = @sprites["logo"].opacity
    end
    
    # Update sparkles
    if @sparkle
      @sparkleData.each_with_index do |data, i|
        sprite = @sprites["sparkle#{i}"]
        next unless sprite && sprite.bitmap
        
        data[:timer] -= 1
        if data[:timer] <= 0 && ! data[:active]
          data[:active] = true
          sprite.x = @sprites["logo"].x + rand(@sprites["logo"].bitmap.width) - @sprites["logo"].bitmap.width / 2
          sprite.y = @sprites["logo"].y + rand(@sprites["logo"].bitmap.height / 2)
          sprite.opacity = 255
          sprite.zoom_x = 0.1
          sprite.zoom_y = 0.1
        end
        
        if data[:active]
          sprite.zoom_x += 0.05
          sprite.zoom_y += 0.05
          sprite.opacity -= 8
          if sprite.opacity <= 0
            data[:active] = false
            data[:timer] = 30 + rand(60)
          end
        end
      end
    end
  end
  
  def dispose
    @sprites.each_key { |key| @sprites[key].dispose }
  end
end