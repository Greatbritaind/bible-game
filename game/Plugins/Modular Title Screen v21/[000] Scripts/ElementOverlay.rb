#===============================================================================
#  Overlay Elements for Modular Title Screen
#===============================================================================

#-------------------------------------------------------------------------------
# Custom image overlay
#-------------------------------------------------------------------------------
class MTS_Element_OLX
  def initialize(viewport, file, z = nil, speed = nil)
    @viewport = viewport
    @sprite = Sprite.new(@viewport)
    
    if pbResolveBitmap("Graphics/MODTS/#{file}")
      @sprite.bitmap = AnimatedBitmap.new("Graphics/MODTS/#{file}").bitmap
    elsif pbResolveBitmap("Graphics/MODTS/overlay")
      @sprite.bitmap = AnimatedBitmap.new("Graphics/MODTS/overlay").bitmap
    end
    
    # Stretch to fill viewport
    if @sprite.bitmap
      @sprite.zoom_x = @viewport.rect.width.to_f / @sprite.bitmap.width
      @sprite.zoom_y = @viewport.rect.height.to_f / @sprite.bitmap.height
    end
    
    @sprite.z = z || 50
    @sprite.opacity = 150
  end
  
  def update; end
  def dispose; @sprite.dispose; end
end

#-------------------------------------------------------------------------------
# Animated scrolling overlay (horizontal)
#-------------------------------------------------------------------------------
class MTS_Element_OL1
  def initialize(viewport, file = nil, z = nil, speed = nil)
    @viewport = viewport
    @sprites = []
    @zoom_y = 1.0
    
    bitmap_path = file ? "Graphics/MODTS/#{file}" : "Graphics/MODTS/overlay1"
    bitmap_path = "Graphics/MODTS/overlay" unless pbResolveBitmap(bitmap_path)
    
    2.times do |i|
      sprite = Sprite.new(@viewport)
      if pbResolveBitmap(bitmap_path)
        sprite.bitmap = AnimatedBitmap.new(bitmap_path).bitmap
        # Stretch vertically to fill viewport
        @zoom_y = @viewport.rect.height.to_f / sprite.bitmap.height
        sprite.zoom_y = @zoom_y
        sprite.x = i * sprite.bitmap.width
      end
      sprite.z = z || 50
      sprite.opacity = 180
      @sprites << sprite
    end
    @speed = speed || 1
  end
  
  def update
    @sprites.each do |sprite|
      next unless sprite.bitmap
      sprite.x -= @speed
      sprite.x += sprite.bitmap.width * 2 if sprite.x <= -sprite.bitmap.width
    end
  end
  
  def dispose
    @sprites.each { |s| s.dispose }
  end
end

#-------------------------------------------------------------------------------
# Animated scrolling overlay (vertical)
#-------------------------------------------------------------------------------
class MTS_Element_OL2
  def initialize(viewport, file = nil, z = nil, speed = nil)
    @viewport = viewport
    @sprites = []
    @zoom_x = 1.0
    
    bitmap_path = file ? "Graphics/MODTS/#{file}" : "Graphics/MODTS/overlay2"
    bitmap_path = "Graphics/MODTS/overlay" unless pbResolveBitmap(bitmap_path)
    
    2.times do |i|
      sprite = Sprite.new(@viewport)
      if pbResolveBitmap(bitmap_path)
        sprite.bitmap = AnimatedBitmap.new(bitmap_path).bitmap
        # Stretch horizontally to fill viewport
        @zoom_x = @viewport.rect.width.to_f / sprite.bitmap.width
        sprite.zoom_x = @zoom_x
        sprite.y = i * sprite.bitmap.height
      end
      sprite.z = z || 50
      sprite.opacity = 180
      @sprites << sprite
    end
    @speed = speed || 1
  end
  
  def update
    @sprites.each do |sprite|
      next unless sprite.bitmap
      sprite.y -= @speed
      sprite.y += sprite.bitmap.height * 2 if sprite.y <= -sprite.bitmap.height
    end
  end
  
  def dispose
    @sprites.each { |s| s.dispose }
  end
end

#-------------------------------------------------------------------------------
# Pulsing opacity overlay
#-------------------------------------------------------------------------------
class MTS_Element_OL3
  def initialize(viewport, file = nil, z = nil, speed = nil)
    @viewport = viewport
    @sprite = Sprite.new(@viewport)
    
    bitmap_path = file ? "Graphics/MODTS/#{file}" : "Graphics/MODTS/overlay3"
    bitmap_path = "Graphics/MODTS/overlay" unless pbResolveBitmap(bitmap_path)
    
    if pbResolveBitmap(bitmap_path)
      @sprite.bitmap = AnimatedBitmap.new(bitmap_path).bitmap
    end
    
    # Stretch to fill viewport
    if @sprite.bitmap
      @sprite.zoom_x = @viewport.rect.width.to_f / @sprite.bitmap.width
      @sprite.zoom_y = @viewport.rect.height.to_f / @sprite.bitmap.height
    end
    
    @sprite.z = z || 50
    @sprite.opacity = 100
    @fade = speed || 2
  end
  
  def update
    @sprite.opacity += @fade
    @fade *= -1 if @sprite. opacity <= 50 || @sprite.opacity >= 200
  end
  
  def dispose
    @sprite.dispose
  end
end

# Additional overlay styles
class MTS_Element_OL4 < MTS_Element_OL1; end
class MTS_Element_OL5 < MTS_Element_OL2; end
class MTS_Element_OL6 < MTS_Element_OL3; end
class MTS_Element_OL7 < MTS_Element_OL1; end