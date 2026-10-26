# frozen_string_literal: false
#
# Bible Game player: an RGSS (RPG Maker XP runtime) implementation for the browser.
# Ruby runs in WebAssembly; drawing, sound and keyboard are done by JavaScript (window.RGSS).
#
# Objects that appear on screen (Sprite, Plane, Viewport) keep their state here and send only
# what changed to JavaScript once per frame. Bitmaps live in JavaScript and are drawn on directly.

require "js"
require "zlib"

module RGSSRuntime
  JSAPI = JS.global[:RGSS]

  def self.call(name, *args)
    JSAPI.call(name, *args)
  end

  # Calls that wait (frames, image decoding, message boxes) block inside JavaScript
  def self.await(name, *args)
    JSAPI.call(name, *args)
  end

  @dirty = []
  @next_id = 0
  class << self
    attr_reader :dirty
  end

  def self.new_id
    @next_id += 1
  end

  def self.mark(obj)
    @dirty << obj
  end

  # Serialize everything that changed since the last frame
  def self.flush
    return "" if @dirty.empty?
    out = +""
    @dirty.each do |o|
      next unless o.instance_variable_get(:@__dirty)
      o.instance_variable_set(:@__dirty, false)
      out << o.__sync << "\n"
    end
    @dirty.clear
    out
  end

  def self.num(v)
    v.is_a?(Float) ? (v.finite? ? v.round(4).to_s : "0") : v.to_i.to_s
  end
end

# Mixin for objects whose changes must reach the renderer
module RGSSSynced
  def __mark
    return if @__dirty
    @__dirty = true
    RGSSRuntime.mark(self)
  end
end

#===============================================================================
# Value types
#===============================================================================
class Rect
  attr_reader :x, :y, :width, :height
  attr_accessor :__owner

  def initialize(x = 0, y = 0, width = 0, height = 0)
    @x = x.to_i
    @y = y.to_i
    @width = width.to_i
    @height = height.to_i
  end

  def set(*args)
    if args.length == 1
      r = args[0]
      @x, @y, @width, @height = r.x, r.y, r.width, r.height
    else
      @x, @y, @width, @height = args[0].to_i, args[1].to_i, args[2].to_i, args[3].to_i
    end
    @__owner&.__mark
    self
  end

  def x=(v); @x = v.to_i; @__owner&.__mark; end
  def y=(v); @y = v.to_i; @__owner&.__mark; end
  def width=(v); @width = v.to_i; @__owner&.__mark; end
  def height=(v); @height = v.to_i; @__owner&.__mark; end

  def empty
    set(0, 0, 0, 0)
  end

  def ==(other)
    other.is_a?(Rect) && @x == other.x && @y == other.y && @width == other.width && @height == other.height
  end

  def to_s
    "(#{@x}, #{@y}, #{@width}, #{@height})"
  end
  alias inspect to_s

  def _dump(_level = 0)
    [@x, @y, @width, @height].pack("l<4")
  end

  def self._load(data)
    new(*data.unpack("l<4"))
  end

  def initialize_copy(_other)
    super
    @__owner = nil
  end
end

class Color
  attr_reader :red, :green, :blue, :alpha
  attr_accessor :__owner

  def initialize(*args)
    @red = @green = @blue = 0.0
    @alpha = 255.0
    args.length == 0 ? set(0, 0, 0, 0) : set(*args)
  end

  def set(*args)
    if args.length == 1
      c = args[0]
      @red, @green, @blue, @alpha = c.red, c.green, c.blue, c.alpha
    else
      @red = clamp(args[0])
      @green = clamp(args[1])
      @blue = clamp(args[2])
      @alpha = clamp(args.length > 3 ? args[3] : 255)
    end
    @__owner&.__mark
    self
  end

  def red=(v); @red = clamp(v); @__owner&.__mark; end
  def green=(v); @green = clamp(v); @__owner&.__mark; end
  def blue=(v); @blue = clamp(v); @__owner&.__mark; end
  def alpha=(v); @alpha = clamp(v); @__owner&.__mark; end

  def ==(other)
    other.is_a?(Color) && @red == other.red && @green == other.green && @blue == other.blue && @alpha == other.alpha
  end

  def to_s
    format("(%f, %f, %f, %f)", @red, @green, @blue, @alpha)
  end
  alias inspect to_s

  def __csv
    "#{RGSSRuntime.num(@red)},#{RGSSRuntime.num(@green)},#{RGSSRuntime.num(@blue)},#{RGSSRuntime.num(@alpha)}"
  end

  def _dump(_level = 0)
    [@red, @green, @blue, @alpha].pack("E4")
  end

  def self._load(data)
    new(*data.unpack("E4"))
  end

  def initialize_copy(_other)
    super
    @__owner = nil
  end

  private

  def clamp(v)
    v = v.to_f
    v < 0 ? 0.0 : (v > 255 ? 255.0 : v)
  end
end

class Tone
  attr_reader :red, :green, :blue, :gray
  attr_accessor :__owner

  def initialize(*args)
    @red = @green = @blue = @gray = 0.0
    set(*args) if args.length > 0
  end

  def set(*args)
    if args.length == 1
      t = args[0]
      @red, @green, @blue, @gray = t.red, t.green, t.blue, t.gray
    else
      @red = clamp(args[0])
      @green = clamp(args[1])
      @blue = clamp(args[2])
      @gray = args.length > 3 ? args[3].to_f.clamp(0.0, 255.0) : 0.0
    end
    @__owner&.__mark
    self
  end

  def red=(v); @red = clamp(v); @__owner&.__mark; end
  def green=(v); @green = clamp(v); @__owner&.__mark; end
  def blue=(v); @blue = clamp(v); @__owner&.__mark; end
  def gray=(v); @gray = v.to_f.clamp(0.0, 255.0); @__owner&.__mark; end

  def ==(other)
    other.is_a?(Tone) && @red == other.red && @green == other.green && @blue == other.blue && @gray == other.gray
  end

  def to_s
    format("(%f, %f, %f, %f)", @red, @green, @blue, @gray)
  end
  alias inspect to_s

  def __csv
    "#{RGSSRuntime.num(@red)},#{RGSSRuntime.num(@green)},#{RGSSRuntime.num(@blue)},#{RGSSRuntime.num(@gray)}"
  end

  def _dump(_level = 0)
    [@red, @green, @blue, @gray].pack("E4")
  end

  def self._load(data)
    new(*data.unpack("E4"))
  end

  def initialize_copy(_other)
    super
    @__owner = nil
  end

  private

  def clamp(v)
    v.to_f.clamp(-255.0, 255.0)
  end
end

class Table
  attr_reader :xsize, :ysize, :zsize

  def initialize(xsize, ysize = 1, zsize = 1)
    @dim = 1 + (ysize > 1 ? 1 : 0) + (zsize > 1 ? 1 : 0)
    @xsize = xsize
    @ysize = ysize
    @zsize = zsize
    @data = Array.new(xsize * ysize * zsize, 0)
  end

  def resize(xsize, ysize = 1, zsize = 1)
    old = @data
    ox, oy, oz = @xsize, @ysize, @zsize
    @dim = 1 + (ysize > 1 ? 1 : 0) + (zsize > 1 ? 1 : 0)
    @xsize, @ysize, @zsize = xsize, ysize, zsize
    @data = Array.new(xsize * ysize * zsize, 0)
    [oz, zsize].min.times do |z|
      [oy, ysize].min.times do |y|
        [ox, xsize].min.times do |x|
          @data[x + (y + z * ysize) * xsize] = old[x + (y + z * oy) * ox]
        end
      end
    end
  end

  def [](x, y = 0, z = 0)
    return nil if x < 0 || y < 0 || z < 0 || x >= @xsize || y >= @ysize || z >= @zsize
    @data[x + (y + z * @ysize) * @xsize]
  end

  def []=(*args)
    value = args.pop
    x, y, z = args[0], args[1] || 0, args[2] || 0
    return if x < 0 || y < 0 || z < 0 || x >= @xsize || y >= @ysize || z >= @zsize
    v = value.to_i
    v = ((v + 32768) % 65536) - 32768
    @data[x + (y + z * @ysize) * @xsize] = v
  end

  def _dump(_level = 0)
    [@dim, @xsize, @ysize, @zsize, @data.length].pack("l<5") + @data.pack("s<*")
  end

  def self._load(data)
    dim, x, y, z, n = data.unpack("l<5")
    t = allocate
    t.instance_variable_set(:@dim, dim)
    t.instance_variable_set(:@xsize, x)
    t.instance_variable_set(:@ysize, y)
    t.instance_variable_set(:@zsize, z)
    t.instance_variable_set(:@data, data.byteslice(20, n * 2).unpack("s<*"))
    t
  end
end

#===============================================================================
# Font
#===============================================================================
class Font
  class << self
    attr_accessor :default_name, :default_size, :default_bold, :default_italic,
                  :default_outline, :default_shadow, :default_strikethrough, :default_underline
    attr_reader :default_color, :default_out_color

    def default_color=(c); @default_color = c.dup; end
    def default_out_color=(c); @default_out_color = c.dup; end

    def exist?(name)
      Array(name).any? { |n| RGSSRuntime.call(:font_exists, n.to_s).to_i == 1 }
    end
  end
  self.default_name = ["Arial"]
  self.default_size = 22
  self.default_bold = false
  self.default_italic = false
  self.default_outline = false
  self.default_shadow = false
  self.default_strikethrough = false
  self.default_underline = false
  self.default_color = Color.new(255, 255, 255, 255)
  self.default_out_color = Color.new(0, 0, 0, 128)

  attr_accessor :name, :size, :bold, :italic, :outline, :shadow, :strikethrough, :underline
  attr_reader :color, :out_color

  def initialize(name = nil, size = nil)
    @name = name || Font.default_name
    @size = size || Font.default_size
    @bold = Font.default_bold
    @italic = Font.default_italic
    @outline = Font.default_outline
    @shadow = Font.default_shadow
    @strikethrough = Font.default_strikethrough
    @underline = Font.default_underline
    @color = Font.default_color.dup
    @out_color = Font.default_out_color.dup
  end

  def color=(c); @color = c.dup; end
  def out_color=(c); @out_color = c.dup; end

  def initialize_copy(other)
    super
    @color = other.color.dup
    @out_color = other.out_color.dup
  end

  # Font names Essentials asks for, as a list for the JavaScript side
  def __names
    Array(@name).map(&:to_s).join("|")
  end
end

#===============================================================================
# Bitmap
#===============================================================================
class Bitmap
  attr_reader :__id

  def self.max_size
    8192
  end

  def initialize(*args)
    @font = Font.new
    @disposed = false
    if args.length == 1
      path = args[0].to_s
      res = RGSSRuntime.await(:bmp_load, path)
      raise Errno::ENOENT, path if res[0].to_i == 0
      @__id = res[0].to_i
      @width = res[1].to_i
      @height = res[2].to_i
    else
      w = [args[0].to_i, 1].max
      h = [args[1].to_i, 1].max
      @width = w
      @height = h
      @__id = RGSSRuntime.call(:bmp_new, w, h).to_i
    end
    ObjectSpace.define_finalizer(self, Bitmap.__finalizer(@__id))
  end

  def self.__finalizer(id)
    proc { RGSSRuntime.call(:bmp_dispose, id) rescue nil }
  end

  def initialize_copy(other)
    @font = other.font.dup
    @disposed = false
    @width = other.width
    @height = other.height
    @__id = RGSSRuntime.call(:bmp_clone, other.__id).to_i
    ObjectSpace.define_finalizer(self, Bitmap.__finalizer(@__id))
  end

  def dispose
    return if @disposed
    @disposed = true
    ObjectSpace.undefine_finalizer(self)
    RGSSRuntime.call(:bmp_dispose, @__id)
  end

  def disposed?
    @disposed
  end

  def width
    check
    @width
  end

  def height
    check
    @height
  end

  def rect
    Rect.new(0, 0, width, height)
  end

  attr_reader :font

  def font=(f)
    @font = f.dup
  end

  def blt(x, y, src, rect, opacity = 255)
    check
    return if src.disposed?
    RGSSRuntime.call(:bmp_blt, @__id, x.to_i, y.to_i, src.__id, rect.x, rect.y, rect.width, rect.height,
                     rect.width, rect.height, opacity.to_i)
  end

  def stretch_blt(dest, src, srect, opacity = 255)
    check
    return if src.disposed?
    RGSSRuntime.call(:bmp_blt, @__id, dest.x, dest.y, src.__id, srect.x, srect.y, srect.width, srect.height,
                     dest.width, dest.height, opacity.to_i)
  end

  def fill_rect(*args)
    check
    if args[0].is_a?(Rect)
      r, c = args
      x, y, w, h = r.x, r.y, r.width, r.height
    else
      x, y, w, h, c = args
    end
    RGSSRuntime.call(:bmp_fill, @__id, x.to_i, y.to_i, w.to_i, h.to_i, c.red, c.green, c.blue, c.alpha)
  end

  def gradient_fill_rect(*args)
    check
    if args[0].is_a?(Rect)
      r, c1, c2, vertical = args
      x, y, w, h = r.x, r.y, r.width, r.height
    else
      x, y, w, h, c1, c2, vertical = args
    end
    RGSSRuntime.call(:bmp_gradient, @__id, x.to_i, y.to_i, w.to_i, h.to_i, c1.__csv, c2.__csv, vertical ? 1 : 0)
  end

  def clear
    check
    RGSSRuntime.call(:bmp_clear, @__id, 0, 0, @width, @height)
  end

  def clear_rect(*args)
    check
    if args[0].is_a?(Rect)
      r = args[0]
      RGSSRuntime.call(:bmp_clear, @__id, r.x, r.y, r.width, r.height)
    else
      RGSSRuntime.call(:bmp_clear, @__id, args[0].to_i, args[1].to_i, args[2].to_i, args[3].to_i)
    end
  end

  def get_pixel(x, y)
    check
    return Color.new(0, 0, 0, 0) if x < 0 || y < 0 || x >= @width || y >= @height
    v = RGSSRuntime.call(:bmp_get_pixel, @__id, x.to_i, y.to_i).to_i
    Color.new((v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255)
  end

  def set_pixel(x, y, c)
    check
    RGSSRuntime.call(:bmp_fill, @__id, x.to_i, y.to_i, 1, 1, c.red, c.green, c.blue, c.alpha)
  end

  def hue_change(hue)
    check
    RGSSRuntime.call(:bmp_hue, @__id, hue.to_i)
  end

  def blur
    check
    RGSSRuntime.call(:bmp_blur, @__id)
  end

  def radial_blur(_angle, _division)
    blur
  end

  def draw_text(*args)
    check
    if args[0].is_a?(Rect)
      r = args[0]
      x, y, w, h = r.x, r.y, r.width, r.height
      str = args[1]
      align = args[2] || 0
    else
      x, y, w, h, str = args
      align = args[5] || 0
    end
    str = str.to_s
    return if str.empty?
    f = @font
    RGSSRuntime.call(:bmp_text, @__id, x.to_i, y.to_i, w.to_i, h.to_i, str, align.to_i,
                     f.__names, f.size.to_i, f.bold ? 1 : 0, f.italic ? 1 : 0,
                     f.color.__csv, f.outline ? 1 : 0, f.out_color.__csv, f.shadow ? 1 : 0)
  end

  def text_size(str)
    check
    w = RGSSRuntime.call(:text_width, str.to_s, @font.__names, @font.size.to_i, @font.bold ? 1 : 0,
                         @font.italic ? 1 : 0).to_i
    h = RGSSRuntime.call(:text_height, str.to_s, @font.__names, @font.size.to_i, @font.bold ? 1 : 0,
                         @font.italic ? 1 : 0).to_i
    Rect.new(0, 0, w, h)
  end

  # mkxp-z animation API (GIFs are shown as still images)
  def animated?; false; end
  def frame_count; 1; end
  def current_frame; 0; end
  def frame_rate; 0; end
  def playing; false; end
  def playing=(_v); end
  def play; end
  def stop; end
  def goto_and_play(_f); end
  def goto_and_stop(_f); end
  def mega?; false; end

  def to_file(_path); end

  private

  def check
    raise RGSSError, "disposed bitmap" if @disposed
  end
end

class RGSSError < StandardError; end

#===============================================================================
# Viewport
#===============================================================================
class Viewport
  include RGSSSynced
  attr_reader :__id, :rect, :visible, :z, :ox, :oy, :color, :tone

  def initialize(*args)
    @__id = RGSSRuntime.new_id
    if args.length == 0
      @rect = Rect.new(0, 0, Graphics.width, Graphics.height)
    elsif args[0].is_a?(Rect)
      @rect = args[0].dup
    else
      @rect = Rect.new(*args)
    end
    @rect.__owner = self
    @visible = true
    @z = 0
    @ox = 0
    @oy = 0
    @color = Color.new(0, 0, 0, 0)
    @color.__owner = self
    @tone = Tone.new(0, 0, 0, 0)
    @tone.__owner = self
    @flash_color = nil
    @flash_duration = 0
    @disposed = false
    __mark
  end

  def rect=(r); @rect = r.dup; @rect.__owner = self; __mark; end
  def visible=(v); @visible = v; __mark; end
  def z=(v); @z = v.to_i; __mark; end
  def ox=(v); @ox = v.to_i; __mark; end
  def oy=(v); @oy = v.to_i; __mark; end
  def color=(c); @color = c.dup; @color.__owner = self; __mark; end
  def tone=(t); @tone = t.dup; @tone.__owner = self; __mark; end

  def flash(color, duration)
    @flash_color = color ? color.dup : nil
    @flash_duration = duration.to_i
    @flash_total = duration.to_i
    __mark
  end

  def update
    return if @flash_duration <= 0
    @flash_duration -= 1
    __mark
  end

  def dispose
    return if @disposed
    @disposed = true
    RGSSRuntime.mark(self)
    @__dirty = true
  end

  def disposed?
    @disposed
  end

  def __sync
    return "X|#{@__id}" if @disposed
    n = RGSSRuntime.method(:num)
    fc = "0,0,0,0"
    if @flash_duration > 0 && @flash_color
      a = @flash_color.alpha * @flash_duration / @flash_total
      fc = "#{n.(@flash_color.red)},#{n.(@flash_color.green)},#{n.(@flash_color.blue)},#{n.(a)}"
    elsif @flash_duration > 0
      fc = "0,0,0,-1"
    end
    "V|#{@__id}|#{@visible ? 1 : 0},#{@z},#{@rect.x},#{@rect.y},#{@rect.width},#{@rect.height},#{@ox},#{@oy}," \
      "#{@color.__csv},#{@tone.__csv},#{fc}"
  end
end

#===============================================================================
# Sprite
#===============================================================================
class Sprite
  include RGSSSynced
  attr_reader :__id, :bitmap, :src_rect, :viewport, :visible, :x, :y, :z, :ox, :oy,
              :zoom_x, :zoom_y, :angle, :mirror, :bush_depth, :bush_opacity, :opacity,
              :blend_type, :color, :tone, :wave_amp, :wave_length, :wave_speed, :wave_phase

  def initialize(viewport = nil)
    @__id = RGSSRuntime.new_id
    @viewport = viewport
    @bitmap = nil
    @src_rect = Rect.new(0, 0, 0, 0)
    @src_rect.__owner = self
    @visible = true
    @x = @y = @z = @ox = @oy = 0
    @zoom_x = @zoom_y = 1.0
    @angle = 0
    @mirror = false
    @bush_depth = 0
    @bush_opacity = 128
    @opacity = 255
    @blend_type = 0
    @color = Color.new(0, 0, 0, 0)
    @color.__owner = self
    @tone = Tone.new(0, 0, 0, 0)
    @tone.__owner = self
    @wave_amp = @wave_length = @wave_speed = 0
    @wave_phase = 0.0
    @flash_color = nil
    @flash_duration = 0
    @disposed = false
    __mark
  end

  def bitmap=(b)
    # Like RPG Maker: assigning the same bitmap again changes nothing (src_rect is kept)
    return if b.equal?(@bitmap)
    @bitmap = b
    @src_rect.set(0, 0, b.width, b.height) if b && !b.disposed?
    __mark
  end

  def src_rect=(r); @src_rect.set(r.x, r.y, r.width, r.height); end
  def viewport=(v); @viewport = v; __mark; end
  def visible=(v); @visible = v; __mark; end
  def x=(v); @x = v; __mark; end
  def y=(v); @y = v; __mark; end
  def z=(v); @z = v.to_i; __mark; end
  def ox=(v); @ox = v; __mark; end
  def oy=(v); @oy = v; __mark; end
  def zoom_x=(v); @zoom_x = v.to_f; __mark; end
  def zoom_y=(v); @zoom_y = v.to_f; __mark; end
  def angle=(v); @angle = v; __mark; end
  def mirror=(v); @mirror = v; __mark; end
  def bush_depth=(v); @bush_depth = v.to_i; __mark; end
  def bush_opacity=(v); @bush_opacity = v.to_i.clamp(0, 255); __mark; end
  def opacity=(v); @opacity = v.to_i.clamp(0, 255); __mark; end
  def blend_type=(v); @blend_type = v.to_i; __mark; end
  def color=(c); @color = c.dup; @color.__owner = self; __mark; end
  def tone=(t); @tone = t.dup; @tone.__owner = self; __mark; end
  def wave_amp=(v); @wave_amp = v; end
  def wave_length=(v); @wave_length = v; end
  def wave_speed=(v); @wave_speed = v; end
  def wave_phase=(v); @wave_phase = v; end

  def width
    @src_rect.width
  end

  def height
    @src_rect.height
  end

  def flash(color, duration)
    @flash_color = color ? color.dup : nil
    @flash_duration = duration.to_i
    @flash_total = [duration.to_i, 1].max
    __mark
  end

  def update
    return if @flash_duration <= 0
    @flash_duration -= 1
    __mark
  end

  def dispose
    return if @disposed
    @disposed = true
    @__dirty = true
    RGSSRuntime.mark(self)
  end

  def disposed?
    @disposed
  end

  def __sync
    return "X|#{@__id}" if @disposed
    n = RGSSRuntime.method(:num)
    bid = (@bitmap && !@bitmap.disposed?) ? @bitmap.__id : 0
    vid = (@viewport && !@viewport.disposed?) ? @viewport.__id : 0
    fc = "0,0,0,0"
    if @flash_duration > 0 && @flash_color
      a = @flash_color.alpha * @flash_duration / @flash_total
      fc = "#{n.(@flash_color.red)},#{n.(@flash_color.green)},#{n.(@flash_color.blue)},#{n.(a)}"
    elsif @flash_duration > 0
      fc = "0,0,0,-1"
    end
    r = @src_rect
    "S|#{@__id}|#{vid},#{bid},#{@visible ? 1 : 0},#{n.(@x)},#{n.(@y)},#{@z},#{n.(@ox)},#{n.(@oy)}," \
      "#{n.(@zoom_x)},#{n.(@zoom_y)},#{n.(@angle)},#{@mirror ? 1 : 0},#{@opacity},#{@blend_type}," \
      "#{r.x},#{r.y},#{r.width},#{r.height},#{@color.__csv},#{@tone.__csv},#{@bush_depth},#{@bush_opacity},#{fc}"
  end
end

#===============================================================================
# Plane (a bitmap repeated across the screen)
#===============================================================================
class Plane
  include RGSSSynced
  attr_reader :__id, :bitmap, :viewport, :visible, :z, :ox, :oy, :zoom_x, :zoom_y,
              :opacity, :blend_type, :color, :tone

  def initialize(viewport = nil)
    @__id = RGSSRuntime.new_id
    @viewport = viewport
    @bitmap = nil
    @visible = true
    @z = @ox = @oy = 0
    @zoom_x = @zoom_y = 1.0
    @opacity = 255
    @blend_type = 0
    @color = Color.new(0, 0, 0, 0)
    @color.__owner = self
    @tone = Tone.new(0, 0, 0, 0)
    @tone.__owner = self
    @disposed = false
    __mark
  end

  def bitmap=(b); @bitmap = b; __mark; end
  def viewport=(v); @viewport = v; __mark; end
  def visible=(v); @visible = v; __mark; end
  def z=(v); @z = v.to_i; __mark; end
  def ox=(v); @ox = v; __mark; end
  def oy=(v); @oy = v; __mark; end
  def zoom_x=(v); @zoom_x = v.to_f; __mark; end
  def zoom_y=(v); @zoom_y = v.to_f; __mark; end
  def opacity=(v); @opacity = v.to_i.clamp(0, 255); __mark; end
  def blend_type=(v); @blend_type = v.to_i; __mark; end
  def color=(c); @color = c.dup; @color.__owner = self; __mark; end
  def tone=(t); @tone = t.dup; @tone.__owner = self; __mark; end

  def dispose
    return if @disposed
    @disposed = true
    @__dirty = true
    RGSSRuntime.mark(self)
  end

  def disposed?
    @disposed
  end

  def __sync
    return "X|#{@__id}" if @disposed
    n = RGSSRuntime.method(:num)
    bid = (@bitmap && !@bitmap.disposed?) ? @bitmap.__id : 0
    vid = (@viewport && !@viewport.disposed?) ? @viewport.__id : 0
    "P|#{@__id}|#{vid},#{bid},#{@visible ? 1 : 0},#{@z},#{n.(@ox)},#{n.(@oy)},#{n.(@zoom_x)},#{n.(@zoom_y)}," \
      "#{@opacity},#{@blend_type},#{@color.__csv},#{@tone.__csv}"
  end
end

#===============================================================================
# Graphics
#===============================================================================
module Graphics
  @frame_count = 0
  @frame_rate = 60
  @brightness = 255
  @width = 640
  @height = 480
  @last_update = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  @delta = 0.0
  @fullscreen = false
  @scale = 1.0

  class << self
    attr_accessor :frame_count, :fullscreen, :scale, :show_cursor
    attr_reader :frame_rate, :brightness, :width, :height, :delta

    def frame_rate=(v); @frame_rate = v.to_i; end

    def brightness=(v)
      @brightness = v.to_i.clamp(0, 255)
      RGSSRuntime.call(:set_brightness, @brightness)
    end

    def update
      Audio.__update
      if $__debug && $__debug_cmd && !$__debug_cmd.empty? && !@__in_transition && @frame_count > 600 && defined?(Scene_Map) && $scene.is_a?(Scene_Map) &&
         $game_temp && !$game_temp.in_menu && !$game_temp.message_window_showing && !(pbMapInterpreterRunning? rescue true)
        cmd = $__debug_cmd
        $__debug_cmd = nil
        puts "[debug] running #{cmd}"
        eval(cmd, TOPLEVEL_BINDING)
      end
      if $__debug && @frame_count % 240 == 120
        where = caller(1, 14).map { |l| l.gsub(/Section(\d+)/) { ($RGSS_SCRIPTS[$1.to_i][1] rescue $1).to_s } }
        puts "[where] " + where.join(" <- ")
      end
      sync = RGSSRuntime.flush
      RGSSRuntime.await(:frame, sync)
      @frame_count += 1
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @delta = now - @last_update
      @last_update = now
      nil
    end

    def wait(duration)
      duration.to_i.times { update }
    end

    def freeze
      RGSSRuntime.call(:freeze, RGSSRuntime.flush)
    end

    def transition(duration = 8, filename = "", vague = 40)
      duration = duration.to_i
      if duration <= 0
        RGSSRuntime.call(:transition_end)
        return
      end
      RGSSRuntime.await(:transition_begin, filename.to_s, vague.to_i)
      @__in_transition = true
      duration.times do |i|
        RGSSRuntime.call(:transition_progress, (i + 1).to_f / duration)
        update
      end
      @__in_transition = false
      RGSSRuntime.call(:transition_end)
    end

    def fadeout(duration)
      start = @brightness
      duration.to_i.times do |i|
        self.brightness = start - start * (i + 1) / duration
        update
      end
    end

    def fadein(duration)
      start = @brightness
      duration.to_i.times do |i|
        self.brightness = start + (255 - start) * (i + 1) / duration
        update
      end
    end

    def frame_reset
      @last_update = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def resize_screen(w, h)
      @width = w.to_i
      @height = h.to_i
      RGSSRuntime.call(:resize_screen, @width, @height)
    end

    def snap_to_bitmap
      b = Bitmap.new(@width, @height)
      RGSSRuntime.call(:snap_to_bitmap, b.__id, RGSSRuntime.flush)
      b
    end

    def screenshot(_path); end
    def center; end
    def average_frame_rate; @frame_rate; end
    def play_movie(_file); end
    def vsync; true; end
    def vsync=(_v); end
  end
end

#===============================================================================
# Input
#===============================================================================
module Input
  DOWN = 2
  LEFT = 4
  RIGHT = 6
  UP = 8
  A = 11
  B = 12
  C = 13
  X = 14
  Y = 15
  Z = 16
  L = 17
  R = 18
  SHIFT = 21
  CTRL = 22
  ALT = 23
  F5 = 25
  F6 = 26
  F7 = 27
  F8 = 28
  F9 = 29
  MOUSELEFT = 38
  MOUSEMIDDLE = 39
  MOUSERIGHT = 40

  # Which keyboard keys (KeyboardEvent.code) press each game button
  BINDINGS = {
    DOWN => %w[ArrowDown],
    LEFT => %w[ArrowLeft],
    RIGHT => %w[ArrowRight],
    UP => %w[ArrowUp],
    # Same keys as Pokémon Essentials on a computer
    C => %w[KeyC Enter NumpadEnter Space],          # Use / Talk
    B => %w[KeyX Escape Backspace Numpad0],         # Back (hold to run)
    A => %w[KeyZ ShiftLeft ShiftRight],             # Action (opens the menu)
    X => %w[KeyA],                                  # Jump up a page
    Y => %w[KeyS],                                  # Jump down a page
    Z => %w[KeyD],                                  # Special (Ready menu)
    L => %w[KeyQ PageUp],
    R => %w[KeyW PageDown],
    SHIFT => %w[ShiftLeft ShiftRight],
    CTRL => %w[ControlLeft ControlRight],
    ALT => %w[AltLeft AltRight],
    F5 => %w[F5], F6 => %w[F6], F7 => %w[F7], F8 => %w[F8], F9 => %w[F9]
  }.freeze

  SYMBOLS = {
    DOWN: DOWN, LEFT: LEFT, RIGHT: RIGHT, UP: UP, A: A, B: B, C: C, X: X, Y: Y, Z: Z,
    L: L, R: R, SHIFT: SHIFT, CTRL: CTRL, ALT: ALT, F5: F5, F6: F6, F7: F7, F8: F8, F9: F9
  }.freeze

  # Keyboard symbols used with Input.pressex? etc. (SDL names -> KeyboardEvent.code)
  KEY_CODES = {
    BACKSPACE: "Backspace", TAB: "Tab", RETURN: "Enter", ESCAPE: "Escape", SPACE: "Space",
    DELETE: "Delete", HOME: "Home", END: "End", PAGEUP: "PageUp", PAGEDOWN: "PageDown",
    LEFT: "ArrowLeft", RIGHT: "ArrowRight", UP: "ArrowUp", DOWN: "ArrowDown",
    KP_MINUS: "NumpadSubtract", KP_PLUS: "NumpadAdd", KP_ENTER: "NumpadEnter",
    LSHIFT: "ShiftLeft", RSHIFT: "ShiftRight", LCTRL: "ControlLeft", RCTRL: "ControlRight",
    LALT: "AltLeft", RALT: "AltRight", INSERT: "Insert"
  }
  ("A".."Z").each { |c| KEY_CODES[c.to_sym] = "Key#{c}" }
  (0..9).each { |d| KEY_CODES[:"NUMBER_#{d}"] = "Digit#{d}"; KEY_CODES[:"KP_#{d}"] = "Numpad#{d}" }
  (1..12).each { |f| KEY_CODES[:"F#{f}"] = "F#{f}" }
  KEY_CODES.freeze

  REPEAT_DELAY = 0.4
  REPEAT_INTERVAL = 0.1

  @key_down = {}       # code -> time pressed
  @key_prev = {}       # code -> true (last frame)
  @button_time = {}    # button -> time pressed
  @button_prev = {}
  @button_now = {}
  @last_repeat = {}
  @dir_order = []
  @text = +""
  @mouse_x = 0
  @mouse_y = 0
  @mouse_in = false
  @frame_time = 0.0

  class << self
    attr_accessor :text_input
    attr_reader :mouse_x, :mouse_y

    def update
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @frame_time = now
      res = RGSSRuntime.call(:input_poll).to_s
      codes, text, mouse = res.split("\u0001", 3)
      @key_prev = @key_down.transform_values { true }
      new_down = {}
      codes.to_s.split(",").each do |c|
        next if c.empty?
        new_down[c] = @key_down[c] || now
      end
      @key_down = new_down
      @text << text.to_s if @text_input
      mx, my, min = (mouse || "0,0,0").split(",")
      @mouse_x = mx.to_i
      @mouse_y = my.to_i
      @mouse_in = min == "1"
      @button_prev = @button_now
      @button_now = {}
      BINDINGS.each do |button, keys|
        t = nil
        keys.each do |k|
          kt = @key_down[k]
          t = kt if kt && (t.nil? || kt < t)
        end
        @button_now[button] = t if t
      end
      # Remember the order directions were pressed in, for dir4/dir8
      [DOWN, LEFT, RIGHT, UP].each do |d|
        if @button_now[d]
          @dir_order.push(d) unless @dir_order.include?(d)
        else
          @dir_order.delete(d)
        end
      end
      nil
    end

    def press?(button)
      b = button_id(button)
      !@button_now[b].nil?
    end

    def trigger?(button)
      b = button_id(button)
      !@button_now[b].nil? && @button_prev[b].nil?
    end

    def repeat?(button)
      b = button_id(button)
      held_repeat?(@button_now[b], @button_prev[b], b)
    end

    def release?(button)
      b = button_id(button)
      @button_now[b].nil? && !@button_prev[b].nil?
    end

    def time?(button)
      b = button_id(button)
      t = @button_now[b]
      t ? ((@frame_time - t) * 1_000_000).to_i : 0
    end

    def count(button)
      b = button_id(button)
      t = @button_now[b]
      t ? ((@frame_time - t) * Graphics.frame_rate).to_i + 1 : 0
    end

    def pressex?(key)
      code = key_code(key)
      !@key_down[code].nil?
    end
    alias press_ex? pressex?

    def triggerex?(key)
      code = key_code(key)
      !@key_down[code].nil? && !@key_prev[code]
    end
    alias trigger_ex? triggerex?

    def repeatex?(key)
      code = key_code(key)
      held_repeat?(@key_down[code], @key_prev[code], code)
    end
    alias repeat_ex? repeatex?

    def releaseex?(key)
      code = key_code(key)
      @key_down[code].nil? && @key_prev[code]
    end
    alias release_ex? releaseex?

    def dir4
      d = @dir_order.last
      d || 0
    end

    def dir8
      up = press?(UP)
      down = press?(DOWN)
      left = press?(LEFT)
      right = press?(RIGHT)
      return 7 if up && left
      return 9 if up && right
      return 1 if down && left
      return 3 if down && right
      dir4
    end

    def dir
      dir4
    end

    def gets
      t = @text
      @text = +""
      t
    end

    def mouse_in_window
      @mouse_in
    end

    def clipboard
      ""
    end

    def clipboard=(text)
      RGSSRuntime.call(:set_clipboard, text.to_s)
    end

    def scroll_v
      0
    end

    private

    def button_id(button)
      button.is_a?(Symbol) ? SYMBOLS[button] : button
    end

    def key_code(key)
      key.is_a?(Symbol) ? KEY_CODES[key] : key
    end

    def held_repeat?(now_t, prev, id)
      return false if now_t.nil?
      return (@last_repeat[id] = @frame_time; true) if prev.nil?
      held = @frame_time - now_t
      return false if held < REPEAT_DELAY
      last = @last_repeat[id] || now_t
      if @frame_time - last >= REPEAT_INTERVAL
        @last_repeat[id] = @frame_time
        return true
      end
      false
    end
  end
end

#===============================================================================
# Audio (played by JavaScript with Web Audio)
#===============================================================================
module Audio
  class << self
    def bgm_play(name, volume = 100, pitch = 100, pos = 0, _track = nil)
      RGSSRuntime.call(:audio_play, "bgm", name.to_s, volume.to_i, pitch.to_i, pos.to_f)
    end
    def bgm_stop(_track = nil); RGSSRuntime.call(:audio_stop, "bgm"); end
    def bgm_fade(ms, _track = nil); RGSSRuntime.call(:audio_fade, "bgm", ms.to_i); end
    def bgm_pos(_track = nil); RGSSRuntime.call(:audio_pos, "bgm").to_f; end
    def bgm_volume(_track = nil); 100; end
    def bgm_set_volume(_v, _track = nil); end

    def bgs_play(name, volume = 80, pitch = 100, pos = 0)
      RGSSRuntime.call(:audio_play, "bgs", name.to_s, volume.to_i, pitch.to_i, pos.to_f)
    end
    def bgs_stop; RGSSRuntime.call(:audio_stop, "bgs"); end
    def bgs_fade(ms); RGSSRuntime.call(:audio_fade, "bgs", ms.to_i); end
    def bgs_pos; RGSSRuntime.call(:audio_pos, "bgs").to_f; end

    def me_play(name, volume = 100, pitch = 100)
      RGSSRuntime.call(:audio_play, "me", name.to_s, volume.to_i, pitch.to_i, 0.0)
    end
    def me_stop; RGSSRuntime.call(:audio_stop, "me"); end
    def me_fade(ms); RGSSRuntime.call(:audio_fade, "me", ms.to_i); end

    def se_play(name, volume = 80, pitch = 100)
      RGSSRuntime.call(:audio_play, "se", name.to_s, volume.to_i, pitch.to_i, 0.0)
    end
    def se_stop; RGSSRuntime.call(:audio_stop, "se"); end

    def __update; end
  end
end

#===============================================================================
# System (mkxp-z extras that Essentials uses)
#===============================================================================
module System
  VERSION = "2.4.2/c9378cf"

  class << self
    def data_directory
      "/save"
    end

    def uptime
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def delta
      (uptime * 1_000_000).to_i
    end

    def set_window_title(title)
      RGSSRuntime.call(:set_title, title.to_s)
    end

    def window_title
      @title || game_title
    end

    def game_title
      $__game_title || "Game"
    end

    def user_language
      RGSSRuntime.call(:user_language).to_s
    end

    def user_name
      "Player"
    end

    def platform
      "Web"
    end

    def is_windows?; false; end
    def is_mac?; false; end
    def is_linux?; false; end
    def is_really_windows?; false; end

    def power_state
      { discharging: false, seconds: nil, percent: nil }
    end

    def nproc; 1; end
    def mount(*_args); end
    def unmount(*_args); end
    def reload_cache; end
    def puts(*args); Kernel.puts(*args); end
    def launch(*_args); end
    def default_font_family; "Arial"; end
  end
end

#===============================================================================
# RPG Maker XP data classes (needed to load the Data/*.rxdata files)
#===============================================================================
module RPG
  class AudioFile
    attr_accessor :name, :volume, :pitch
    def initialize(name = "", volume = 100, pitch = 100)
      @name = name
      @volume = volume
      @pitch = pitch
    end
  end

  class BGM < AudioFile; end
  class BGS < AudioFile; end
  class ME < AudioFile; end
  class SE < AudioFile; end

  class Map
    attr_accessor :tileset_id, :width, :height, :autoplay_bgm, :bgm, :autoplay_bgs, :bgs,
                  :encounter_list, :encounter_step, :data, :events
    def initialize(width = 20, height = 15)
      @tileset_id = 1
      @width = width
      @height = height
      @autoplay_bgm = false
      @bgm = RPG::AudioFile.new
      @autoplay_bgs = false
      @bgs = RPG::AudioFile.new("", 80)
      @encounter_list = []
      @encounter_step = 30
      @data = Table.new(width, height, 3)
      @events = {}
    end
  end

  class MapInfo
    attr_accessor :name, :parent_id, :order, :expanded, :scroll_x, :scroll_y
    def initialize
      @name = ""
      @parent_id = 0
      @order = 0
      @expanded = false
      @scroll_x = 0
      @scroll_y = 0
    end
  end

  class Event
    attr_accessor :id, :name, :x, :y, :pages
    def initialize(x = 0, y = 0)
      @id = 0
      @name = ""
      @x = x
      @y = y
      @pages = [RPG::Event::Page.new]
    end

    class Page
      attr_accessor :condition, :graphic, :move_type, :move_speed, :move_frequency, :move_route,
                    :walk_anime, :step_anime, :direction_fix, :through, :always_on_top, :trigger, :list
      def initialize
        @condition = RPG::Event::Page::Condition.new
        @graphic = RPG::Event::Page::Graphic.new
        @move_type = 0
        @move_speed = 3
        @move_frequency = 3
        @move_route = RPG::MoveRoute.new
        @walk_anime = true
        @step_anime = false
        @direction_fix = false
        @through = false
        @always_on_top = false
        @trigger = 0
        @list = [RPG::EventCommand.new]
      end

      class Condition
        attr_accessor :switch1_valid, :switch2_valid, :variable_valid, :self_switch_valid,
                      :switch1_id, :switch2_id, :variable_id, :variable_value, :self_switch_ch
        def initialize
          @switch1_valid = false
          @switch2_valid = false
          @variable_valid = false
          @self_switch_valid = false
          @switch1_id = 1
          @switch2_id = 1
          @variable_id = 1
          @variable_value = 0
          @self_switch_ch = "A"
        end
      end

      class Graphic
        attr_accessor :tile_id, :character_name, :character_hue, :direction, :pattern, :opacity, :blend_type
        def initialize
          @tile_id = 0
          @character_name = ""
          @character_hue = 0
          @direction = 2
          @pattern = 0
          @opacity = 255
          @blend_type = 0
        end
      end
    end
  end

  class EventCommand
    attr_accessor :code, :indent, :parameters
    def initialize(code = 0, indent = 0, parameters = [])
      @code = code
      @indent = indent
      @parameters = parameters
    end
  end

  class MoveRoute
    attr_accessor :repeat, :skippable, :list
    def initialize
      @repeat = true
      @skippable = false
      @list = [RPG::MoveCommand.new]
    end
  end

  class MoveCommand
    attr_accessor :code, :parameters
    def initialize(code = 0, parameters = [])
      @code = code
      @parameters = parameters
    end
  end

  class Actor
    attr_accessor :id, :name, :class_id, :initial_level, :final_level, :exp_basis, :exp_inflation,
                  :character_name, :character_hue, :battler_name, :battler_hue, :parameters,
                  :weapon_id, :armor1_id, :armor2_id, :armor3_id, :armor4_id, :weapon_fix,
                  :armor1_fix, :armor2_fix, :armor3_fix, :armor4_fix
  end

  class Class
    attr_accessor :id, :name, :position, :weapon_set, :armor_set, :element_ranks, :state_ranks, :learnings
    class Learning
      attr_accessor :level, :skill_id
    end
  end

  class Skill
    attr_accessor :id, :name, :icon_name, :description, :scope, :occasion, :animation1_id, :animation2_id,
                  :menu_se, :common_event_id, :sp_cost, :power, :atk_f, :eva_f, :str_f, :dex_f, :agi_f,
                  :int_f, :hit, :pdef_f, :mdef_f, :variance, :element_set, :plus_state_set, :minus_state_set
  end

  class Item
    attr_accessor :id, :name, :icon_name, :description, :scope, :occasion, :animation1_id, :animation2_id,
                  :menu_se, :common_event_id, :price, :consumable, :parameter_type, :parameter_points,
                  :recover_hp_rate, :recover_hp, :recover_sp_rate, :recover_sp, :hit, :pdef_f, :mdef_f,
                  :variance, :element_set, :plus_state_set, :minus_state_set
  end

  class Weapon
    attr_accessor :id, :name, :icon_name, :description, :animation1_id, :animation2_id, :price, :atk,
                  :pdef, :mdef, :str_plus, :dex_plus, :agi_plus, :int_plus, :element_set,
                  :plus_state_set, :minus_state_set
  end

  class Armor
    attr_accessor :id, :name, :icon_name, :description, :kind, :auto_state_id, :price, :pdef, :mdef,
                  :eva, :str_plus, :dex_plus, :agi_plus, :int_plus, :guard_element_set, :guard_state_set
  end

  class Enemy
    attr_accessor :id, :name, :battler_name, :battler_hue, :maxhp, :maxsp, :str, :dex, :agi, :int,
                  :atk, :pdef, :mdef, :eva, :animation1_id, :animation2_id, :element_ranks, :state_ranks,
                  :actions, :exp, :gold, :item_id, :weapon_id, :armor_id, :treasure_prob
    class Action
      attr_accessor :kind, :basic, :skill_id, :condition_turn_a, :condition_turn_b, :condition_hp,
                    :condition_level, :condition_switch_id, :rating
    end
  end

  class Troop
    attr_accessor :id, :name, :members, :pages
    class Member
      attr_accessor :enemy_id, :x, :y, :hidden, :immortal
    end
    class Page
      attr_accessor :condition, :span, :list
      class Condition
        attr_accessor :turn_valid, :enemy_valid, :actor_valid, :switch_valid, :turn_a, :turn_b,
                      :enemy_index, :enemy_hp, :actor_id, :actor_hp, :switch_id
      end
    end
  end

  class State
    attr_accessor :id, :name, :animation_id, :restriction, :nonresistance, :zero_hp, :cant_get_exp,
                  :cant_evade, :slip_damage, :rating, :hit_rate, :maxhp_rate, :maxsp_rate, :str_rate,
                  :dex_rate, :agi_rate, :int_rate, :atk_rate, :pdef_rate, :mdef_rate, :eva,
                  :battle_only, :hold_turn, :auto_release_prob, :shock_release_prob, :guard_element_set,
                  :plus_state_set, :minus_state_set
  end

  class Animation
    attr_accessor :id, :name, :animation_name, :animation_hue, :position, :frame_max, :frames, :timings
    def initialize
      @id = 0
      @name = ""
      @animation_name = ""
      @animation_hue = 0
      @position = 1
      @frame_max = 1
      @frames = [RPG::Animation::Frame.new]
      @timings = []
    end

    class Frame
      attr_accessor :cell_max, :cell_data
      def initialize
        @cell_max = 0
        @cell_data = Table.new(0, 0)
      end
    end

    class Timing
      attr_accessor :frame, :se, :flash_scope, :flash_color, :flash_duration, :condition
      def initialize
        @frame = 0
        @se = RPG::AudioFile.new("", 80)
        @flash_scope = 0
        @flash_color = Color.new(255, 255, 255, 255)
        @flash_duration = 5
        @condition = 0
      end
    end
  end

  class Tileset
    attr_accessor :id, :name, :tileset_name, :autotile_names, :panorama_name, :panorama_hue,
                  :fog_name, :fog_hue, :fog_opacity, :fog_blend_type, :fog_zoom, :fog_sx, :fog_sy,
                  :battleback_name, :passages, :priorities, :terrain_tags
    def initialize
      @id = 0
      @name = ""
      @tileset_name = ""
      @autotile_names = [""] * 7
      @panorama_name = ""
      @panorama_hue = 0
      @fog_name = ""
      @fog_hue = 0
      @fog_opacity = 64
      @fog_blend_type = 0
      @fog_zoom = 200
      @fog_sx = 0
      @fog_sy = 0
      @battleback_name = ""
      @passages = Table.new(384)
      @priorities = Table.new(384)
      @priorities[0] = 5
      @terrain_tags = Table.new(384)
    end
  end

  class CommonEvent
    attr_accessor :id, :name, :trigger, :switch_id, :list
    def initialize
      @id = 0
      @name = ""
      @trigger = 0
      @switch_id = 1
      @list = [RPG::EventCommand.new]
    end
  end

  class System
    attr_accessor :magic_number, :party_members, :elements, :switches, :variables, :windowskin_name,
                  :title_name, :gameover_name, :battle_transition, :title_bgm, :battle_bgm,
                  :battle_end_me, :gameover_me, :cursor_se, :decision_se, :cancel_se, :buzzer_se,
                  :equip_se, :shop_se, :save_se, :load_se, :battle_start_se, :escape_se,
                  :actor_collapse_se, :enemy_collapse_se, :words, :test_battlers, :test_troop_id,
                  :start_map_id, :start_x, :start_y, :battleback_name, :battler_name, :battler_hue,
                  :edit_map_id

    class Words
      attr_accessor :gold, :hp, :sp, :str, :dex, :agi, :int, :atk, :pdef, :mdef, :weapon, :armor1,
                    :armor2, :armor3, :armor4, :attack, :skill, :guard, :item, :equip
    end

    class TestBattler
      attr_accessor :actor_id, :level, :weapon_id, :armor1_id, :armor2_id, :armor3_id, :armor4_id
    end
  end
end

#===============================================================================
# Kernel functions RPG Maker provides
#===============================================================================
module RPG
  # RPG Maker's built-in bitmap cache (Essentials adds its own methods to it)
  module Cache
    @cache = {}

    def self.load_bitmap(folder_name, filename, hue = 0)
      path = folder_name + filename
      if !@cache.include?(path) || @cache[path].disposed?
        @cache[path] = filename.empty? ? Bitmap.new(32, 32) : Bitmap.new(path)
      end
      if hue == 0
        @cache[path]
      else
        key = [path, hue]
        if !@cache.include?(key) || @cache[key].disposed?
          @cache[key] = @cache[path].clone
          @cache[key].hue_change(hue)
        end
        @cache[key]
      end
    end

    %w[animation:Graphics/Animations/ autotile:Graphics/Autotiles/ battleback:Graphics/Battlebacks/
       battler:Graphics/Battlers/ character:Graphics/Characters/ fog:Graphics/Fogs/
       gameover:Graphics/Gameovers/ icon:Graphics/Icons/ panorama:Graphics/Panoramas/
       picture:Graphics/Pictures/ tileset:Graphics/Tilesets/ title:Graphics/Titles/
       windowskin:Graphics/Windowskins/].each do |pair|
      name, folder = pair.split(":")
      define_singleton_method(name) { |filename, hue = 0| load_bitmap(folder, filename, hue) }
    end

    def self.clear
      @cache = {}
      GC.start
    end
  end
end

class Reset < Exception; end unless defined?(Reset)

# Every Marshal load (data files, Essentials' message files) gets UTF-8 text
module Marshal
  class << self
    alias rgss_original_load load
    def load(source, proc = nil, **kwargs)
      rgss_original_load(source, proc || Kernel::RGSS_UTF8_PROC, **kwargs)
    end
    alias restore load
  end
end

module Kernel
  # RPG Maker's data files store text without an encoding; it is UTF-8, so mark it as such
  # (otherwise letters like "é" get split into two broken characters)
  RGSS_UTF8_PROC = lambda do |obj|
    if obj.is_a?(String) && obj.encoding == Encoding::BINARY && !obj.frozen?
      obj.force_encoding(Encoding::UTF_8)
      obj.force_encoding(Encoding::BINARY) unless obj.valid_encoding?
    end
    obj
  end

  def load_data(path)
    File.open(path.to_s.tr("\\", "/"), "rb") { |f| Marshal.load(f) }
  end

  def save_data(obj, path)
    File.open(path.to_s.tr("\\", "/"), "wb") { |f| Marshal.dump(obj, f) }
  end

  # RPG Maker shows print/p output in a message box
  def msgbox(*args)
    text = args.map(&:to_s).join
    $stderr.puts(text)
    RGSSRuntime.await(:message_box, text)
    nil
  end

  def print(*args)
    msgbox(*args)
  end

  def msgbox_p(*args)
    msgbox(args.map(&:inspect).join("\n"))
  end

  def rgss_main
    yield
  end

  def rgss_stop
    loop { Graphics.update }
  end
end
