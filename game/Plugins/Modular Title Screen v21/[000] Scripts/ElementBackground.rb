#===============================================================================
#  Background Elements for Modular Title Screen
#===============================================================================

#-------------------------------------------------------------------------------
# Default/fallback background
#-------------------------------------------------------------------------------
class MTS_Element_BG0
  def initialize(viewport, file = nil)
    @viewport = viewport
    @sprite = Sprite.new(@viewport)
    
    if file && pbResolveBitmap("Graphics/MODTS/#{file}")
      @sprite.bitmap = AnimatedBitmap.new("Graphics/MODTS/#{file}").bitmap
    elsif pbResolveBitmap("Graphics/MODTS/bg0")
      @sprite.bitmap = AnimatedBitmap.new("Graphics/MODTS/bg0").bitmap
    elsif pbResolveBitmap("Graphics/Titles/title")
      @sprite.bitmap = AnimatedBitmap.new("Graphics/Titles/title").bitmap
    else
      @sprite.bitmap = Bitmap.new(Graphics.width, Graphics.height)
      @sprite.bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(0, 0, 0))
    end
    @sprite.z = 0
  end
  
  def update; end
  def dispose; @sprite.dispose; end
end

#-------------------------------------------------------------------------------
# Scrolling background (horizontal)
#-------------------------------------------------------------------------------
class MTS_Element_BG1 < MTS_Element_BG0
  def initialize(viewport, file = nil)
    @viewport = viewport
    @sprites = []
    
    bitmap_path = file ? "Graphics/MODTS/#{file}" : "Graphics/MODTS/bg1"
    bitmap_path = "Graphics/Titles/title" unless pbResolveBitmap(bitmap_path)
    
    2.times do |i|
      sprite = Sprite.new(@viewport)
      sprite.bitmap = AnimatedBitmap.new(bitmap_path).bitmap
      sprite.x = i * sprite.bitmap.width
      sprite. z = 0
      @sprites << sprite
    end
    @speed = 1
  end
  
  def update
    @sprites.each do |sprite|
      sprite.x -= @speed
      sprite.x += sprite.bitmap.width * 2 if sprite.x <= -sprite.bitmap.width
    end
  end
  
  def dispose
    @sprites.each { |s| s.dispose }
  end
end

#-------------------------------------------------------------------------------
# Scrolling background (vertical)
#-------------------------------------------------------------------------------
class MTS_Element_BG2 < MTS_Element_BG0
  def initialize(viewport, file = nil)
    @viewport = viewport
    @sprites = []
    
    bitmap_path = file ?  "Graphics/MODTS/#{file}" : "Graphics/MODTS/bg2"
    bitmap_path = "Graphics/Titles/title" unless pbResolveBitmap(bitmap_path)
    
    2.times do |i|
      sprite = Sprite.new(@viewport)
      sprite.bitmap = AnimatedBitmap.new(bitmap_path).bitmap
      sprite.y = i * sprite.bitmap. height
      sprite.z = 0
      @sprites << sprite
    end
    @speed = 1
  end
  
  def update
    @sprites.each do |sprite|
      sprite. y -= @speed
      sprite. y += sprite.bitmap.height * 2 if sprite.y <= -sprite.bitmap.height
    end
  end
  
  def dispose
    @sprites.each { |s| s.dispose }
  end
end

#-------------------------------------------------------------------------------
# Animated sprite sheet background
#-------------------------------------------------------------------------------
class MTS_Element_BG3 < MTS_Element_BG0
  def initialize(viewport, file = nil)
    @viewport = viewport
    @sprite = Sprite.new(@viewport)
    
    bitmap_path = file ? "Graphics/MODTS/#{file}" :  "Graphics/MODTS/bg3"
    bitmap_path = "Graphics/Titles/title" unless pbResolveBitmap(bitmap_path)
    
    @full_bitmap = AnimatedBitmap.new(bitmap_path).bitmap
    @frame_width = Graphics.width
    @total_frames = @full_bitmap. width / @frame_width
    @total_frames = 1 if @total_frames < 1
    @current_frame = 0
    @frame_delay = 6
    @frame_counter = 0
    
    @sprite.bitmap = Bitmap.new(@frame_width, @full_bitmap.height)
    @sprite.z = 0
    updateFrame
  end
  
  def updateFrame
    @sprite.bitmap.clear
    src_rect = Rect.new(@current_frame * @frame_width, 0, @frame_width, @full_bitmap.height)
    @sprite.bitmap.blt(0, 0, @full_bitmap, src_rect)
  end
  
  def update
    @frame_counter += 1
    if @frame_counter >= @frame_delay
      @frame_counter = 0
      @current_frame = (@current_frame + 1) % @total_frames
      updateFrame
    end
  end
  
  def dispose
    @sprite.dispose
    @full_bitmap.dispose
  end
end

#-------------------------------------------------------------------------------
# Color cycling background
#-------------------------------------------------------------------------------
class MTS_Element_BG4 < MTS_Element_BG0
  def initialize(viewport, file = nil)
    super(viewport, file)
    @hue = 0
  end
  
  def update
    @hue = (@hue + 1) % 360
    @sprite.tone = Tone.new(
      Math.sin(@hue * Math::PI / 180) * 30,
      Math.sin((@hue + 120) * Math::PI / 180) * 30,
      Math.sin((@hue + 240) * Math::PI / 180) * 30
    )
  end
end

#-------------------------------------------------------------------------------
# Numbered frame animation background (for GIF-style animations)
# Loads frames from Graphics/MODTS/<folder>/000.png, 001.png, etc.
#-------------------------------------------------------------------------------
class MTS_Element_BG5 < MTS_Element_BG0
  def initialize(viewport, file = nil)
    @viewport = viewport
    @sprite = Sprite.new(@viewport)
    @sprite.z = 0
    
    # Get settings from config
    folder = ModularTitle::BACKGROUND_FOLDER || "Backgrounds"
    @frame_count = ModularTitle::BACKGROUND_FRAME_COUNT || 1
    @frame_delay = ModularTitle::BACKGROUND_FRAME_DELAY || 4
    
    # Load all frames into memory
    @frames = []
    @frame_count.times do |i|
      frame_path = sprintf("Graphics/MODTS/%s/%03d", folder, i)
      if pbResolveBitmap(frame_path)
        @frames << AnimatedBitmap.new(frame_path).bitmap
      end
    end
    
    # Fallback if no frames found
    if @frames.empty?
      if pbResolveBitmap("Graphics/MODTS/bg0")
        @frames << AnimatedBitmap.new("Graphics/MODTS/bg0").bitmap
      elsif pbResolveBitmap("Graphics/Titles/title")
        @frames << AnimatedBitmap.new("Graphics/Titles/title").bitmap
      else
        bmp = Bitmap.new(Graphics.width, Graphics.height)
        bmp.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(0, 0, 0))
        @frames << bmp
      end
    end
    
    @current_frame = 0
    @frame_counter = 0
    @sprite.bitmap = @frames[@current_frame]
  end
  
  def update
    return if @frames.length <= 1
    @frame_counter += 1
    if @frame_counter >= @frame_delay
      @frame_counter = 0
      @current_frame = (@current_frame + 1) % @frames.length
      @sprite.bitmap = @frames[@current_frame]
    end
  end
  
  def dispose
    @sprite.dispose
    # Note: Don't dispose @frames bitmaps as they may be cached
  end
end

# Additional background style aliases
class MTS_Element_BG6 < MTS_Element_BG1; end
class MTS_Element_BG7 < MTS_Element_BG2; end
class MTS_Element_BG8 < MTS_Element_BG3; end
class MTS_Element_BG9 < MTS_Element_BG4; end
class MTS_Element_BG10 < MTS_Element_BG2; end
class MTS_Element_BG11 < MTS_Element_BG3; end