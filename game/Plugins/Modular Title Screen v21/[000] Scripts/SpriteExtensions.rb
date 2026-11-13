#===============================================================================
#  Sprite Extensions for Modular Title Screen
#===============================================================================
class Sprite
  #-----------------------------------------------------------------------------
  # Center the sprite's origin
  #-----------------------------------------------------------------------------
  def center!(vertical = false)
    return if ! self.bitmap
    self.ox = self.bitmap.width / 2
    self.oy = vertical ? self.bitmap.height / 2 : 0
  end
  
  #-----------------------------------------------------------------------------
  # Set sprite to screen center
  #-----------------------------------------------------------------------------
  def toScreenCenter
    self.x = Graphics.width / 2
    self.y = Graphics.height / 2
  end
end

#===============================================================================
#  AnimatedBitmap Extensions
#===============================================================================
class AnimatedBitmap
  def width
    return @bitmap.width if @bitmap
    return 0
  end
  
  def height
    return @bitmap.height if @bitmap
    return 0
  end
end