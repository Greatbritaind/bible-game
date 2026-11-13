#===============================================================================
#  Particle Effect Elements for Modular Title Screen
#===============================================================================

#-------------------------------------------------------------------------------
# Base particle effect class
#-------------------------------------------------------------------------------
class MTS_Element_FX_Base
  def initialize(viewport, x = nil, y = nil, z = nil)
    @viewport = viewport
    @baseX = x ?  x. to_i : Graphics.width / 2
    @baseY = y ? y.to_i : Graphics.height / 2
    @baseZ = z ? z.to_i : 25
    @sprites = []
  end
  
  def update
    @sprites.each { |s| updateParticle(s) }
  end
  
  def updateParticle(sprite)
    # Override in subclasses
  end
  
  def dispose
    @sprites.each { |s| s. dispose }
  end
end

#-------------------------------------------------------------------------------
# Rising particles (like embers/bubbles)
#-------------------------------------------------------------------------------
class MTS_Element_FX1 < MTS_Element_FX_Base
  def initialize(viewport, x = nil, y = nil, z = nil)
    super
    @baseY = y ? y.to_i : Graphics.height
    
    20.times do |i|
      sprite = Sprite.new(@viewport)
      if pbResolveBitmap("Graphics/MODTS/particle1")
        sprite.bitmap = AnimatedBitmap.new("Graphics/MODTS/particle1").bitmap
      else
        sprite.bitmap = Bitmap.new(8, 8)
        sprite.bitmap.fill_rect(0, 0, 8, 8, Color.new(255, 255, 255, 200))
      end
      sprite.ox = sprite.bitmap.width / 2
      sprite.oy = sprite. bitmap.height / 2
      sprite.x = rand(Graphics.width)
      sprite.y = @baseY + rand(100)
      sprite.z = @baseZ
      sprite.opacity = rand(200) + 55
      sprite.zoom_x = 0.5 + rand * 0.5
      sprite. zoom_y = sprite.zoom_x
      @sprites << sprite
      @sprites[i]. id = { :speed => 0.5 + rand * 1.5, :sway => rand * 2 }
    end
  end
  
  def updateParticle(sprite)
    data = sprite.id
    sprite.y -= data[:speed]
    sprite. x += Math.sin(sprite.y / 30.0) * data[:sway]
    sprite.opacity -= 1
    
    if sprite.y < -20 || sprite.opacity <= 0
      sprite.y = @baseY + rand(50)
      sprite.x = rand(Graphics.width)
      sprite.opacity = rand(200) + 55
    end
  end
end

#-------------------------------------------------------------------------------
# Falling particles (like snow/leaves)
#-------------------------------------------------------------------------------
class MTS_Element_FX2 < MTS_Element_FX_Base
  def initialize(viewport, x = nil, y = nil, z = nil)
    super
    @baseY = y ?  y.to_i : 0
    
    25.times do |i|
      sprite = Sprite.new(@viewport)
      if pbResolveBitmap("Graphics/MODTS/particle2")
        sprite.bitmap = AnimatedBitmap.new("Graphics/MODTS/particle2").bitmap
      else
        sprite.bitmap = Bitmap.new(6, 6)
        sprite.bitmap.fill_rect(0, 0, 6, 6, Color.new(255, 255, 255, 180))
      end
      sprite. ox = sprite.bitmap.width / 2
      sprite.oy = sprite.bitmap.height / 2
      sprite.x = rand(Graphics.width)
      sprite.y = rand(Graphics.height)
      sprite.z = @baseZ
      sprite.opacity = rand(150) + 100
      sprite.zoom_x = 0.3 + rand * 0.7
      sprite.zoom_y = sprite.zoom_x
      @sprites << sprite
      @sprites[i].id = { :speed => 0.5 + rand * 1.0, :sway => rand * 1.5 }
    end
  end
  
  def updateParticle(sprite)
    data = sprite.id
    sprite.y += data[:speed]
    sprite. x += Math.sin(sprite. y / 40.0) * data[:sway]
    
    if sprite.y > Graphics. height + 20
      sprite.y = -10
      sprite.x = rand(Graphics.width)
    end
  end
end

#-------------------------------------------------------------------------------
# Floating/drifting particles
#-------------------------------------------------------------------------------
class MTS_Element_FX3 < MTS_Element_FX_Base
  def initialize(viewport, x = nil, y = nil, z = nil)
    super
    
    15.times do |i|
      sprite = Sprite.new(@viewport)
      if pbResolveBitmap("Graphics/MODTS/particle3")
        sprite.bitmap = AnimatedBitmap.new("Graphics/MODTS/particle3").bitmap
      else
        sprite.bitmap = Bitmap.new(12, 12)
        sprite.bitmap.fill_rect(0, 0, 12, 12, Color.new(255, 255, 255, 150))
      end
      sprite.ox = sprite.bitmap.width / 2
      sprite.oy = sprite.bitmap.height / 2
      sprite.x = rand(Graphics.width)
      sprite.y = rand(Graphics.height)
      sprite.z = @baseZ
      sprite.opacity = rand(100) + 100
      sprite.zoom_x = 0.5 + rand * 0.5
      sprite.zoom_y = sprite.zoom_x
      @sprites << sprite
      @sprites[i].id = { 
        :angle => rand * 360, 
        :speed => 0.3 + rand * 0.5,
        :fade => rand(3) + 1
      }
    end
  end
  
  def updateParticle(sprite)
    data = sprite.id
    data[:angle] += data[:speed]
    sprite.x += Math.cos(data[:angle] * Math::PI / 180) * 0.5
    sprite.y += Math. sin(data[:angle] * Math::PI / 180) * 0.5
    sprite.opacity += data[:fade]
    data[:fade] *= -1 if sprite.opacity <= 80 || sprite.opacity >= 200
    
    # Wrap around screen
    sprite.x = Graphics.width if sprite.x < 0
    sprite.x = 0 if sprite.x > Graphics.width
    sprite.y = Graphics.height if sprite.y < 0
    sprite.y = 0 if sprite.y > Graphics.height
  end
end

#-------------------------------------------------------------------------------
# Sparkle/twinkle effect
#-------------------------------------------------------------------------------
class MTS_Element_FX4 < MTS_Element_FX_Base
  def initialize(viewport, x = nil, y = nil, z = nil)
    super
    
    30.times do |i|
      sprite = Sprite.new(@viewport)
      if pbResolveBitmap("Graphics/MODTS/sparkle")
        sprite.bitmap = AnimatedBitmap.new("Graphics/MODTS/sparkle").bitmap
      else
        sprite.bitmap = Bitmap.new(4, 4)
        sprite.bitmap.fill_rect(0, 0, 4, 4, Color.new(255, 255, 255))
      end
      sprite.ox = sprite.bitmap.width / 2
      sprite.oy = sprite.bitmap.height / 2
      sprite.x = rand(Graphics.width)
      sprite.y = rand(Graphics.height)
      sprite.z = @baseZ
      sprite.opacity = 0
      @sprites << sprite
      @sprites[i].id = { 
        :timer => rand(60),
        :active => false,
        :fade => 8
      }
    end
  end
  
  def updateParticle(sprite)
    data = sprite.id
    
    if ! data[:active]
      data[:timer] -= 1
      if data[:timer] <= 0
        data[:active] = true
        sprite.x = rand(Graphics.width)
        sprite.y = rand(Graphics.height)
        sprite.zoom_x = 0.1
        sprite.zoom_y = 0.1
        data[:fade] = 8
      end
    else
      sprite.opacity += data[:fade]
      sprite.zoom_x += 0.02
      sprite.zoom_y += 0.02
      
      if sprite.opacity >= 255
        data[:fade] = -8
      elsif sprite.opacity <= 0
        data[:active] = false
        data[:timer] = 20 + rand(40)
        sprite.opacity = 0
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Light rays effect
#-------------------------------------------------------------------------------
class MTS_Element_FX5 < MTS_Element_FX_Base
  def initialize(viewport, x = nil, y = nil, z = nil)
    super
    
    if pbResolveBitmap("Graphics/MODTS/ray")
      6.times do |i|
        sprite = Sprite.new(@viewport)
        sprite.bitmap = AnimatedBitmap.new("Graphics/MODTS/ray").bitmap
        sprite.ox = 0
        sprite.oy = sprite.bitmap.height / 2
        sprite.x = @baseX
        sprite.y = @baseY
        sprite.z = @baseZ
        sprite.opacity = rand(100) + 50
        sprite.angle = i * 60 + rand(30)
        @sprites << sprite
        @sprites[i].id = { :rot_speed => 0.1 + rand * 0.2, :fade => rand(3) + 1 }
      end
    end
  end
  
  def updateParticle(sprite)
    data = sprite.id
    sprite.angle += data[:rot_speed]
    sprite.opacity += data[:fade]
    data[:fade] *= -1 if sprite.opacity <= 30 || sprite.opacity >= 150
  end
end

# Additional effect variations
class MTS_Element_FX6 < MTS_Element_FX2; end
class MTS_Element_FX7 < MTS_Element_FX3; end
class MTS_Element_FX8 < MTS_Element_FX4; end
class MTS_Element_FX9 < MTS_Element_FX1; end
class MTS_Element_FX10 < MTS_Element_FX5; end
class MTS_Element_FX11 < MTS_Element_FX4; end