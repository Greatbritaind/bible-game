#===============================================================================
#  Road to Jerusalem: slow, solid drifting clouds
#  Makes the horizontal scrolling overlay (OVERLAY_TYPE 1, Graphics/MODTS/overlay1)
#  move slowly, stay fully opaque, and fade in with the rest of the title screen.
#===============================================================================
class MTS_Element_OL1
  # How many frames to wait between each 1-pixel step (60 frames = 1 second).
  # 4 = a cloud crosses the screen in about 35 seconds. Bigger = slower.
  CLOUD_FRAMES_PER_PIXEL = 4

  alias rtj_clouds_initialize initialize
  def initialize(*args)
    rtj_clouds_initialize(*args)
    @rtj_tick = 0
    @sprites.each { |s| s.opacity = 255 }
  end

  def update
    @rtj_tick += 1
    return if @rtj_tick % CLOUD_FRAMES_PER_PIXEL != 0
    @sprites.each do |sprite|
      next unless sprite.bitmap
      sprite.x -= 1
      sprite.x += sprite.bitmap.width * 2 if sprite.x <= -sprite.bitmap.width
    end
  end

  # Lets the intro animation fade the clouds in with everything else
  def opacity=(value)
    @sprites.each { |s| s.opacity = value }
  end
end
