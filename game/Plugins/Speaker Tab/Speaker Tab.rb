#===============================================================================
# Speaker Tab
# Lines written as "\bShepherd: Want to battle?" show the name on a small wooden
# plaque above the text box, and the box shows just "Want to battle?".
# Only lines that start with a color code (\b, \r or \c[n]) count, so signs like
# "Master: Jotham the Stonecutter" are left alone.
# The next boxes in the same color keep the plaque, so a reader always knows who
# is talking, until a narrator line or a different speaker comes along.
#===============================================================================
module SpeakerTab
  NAME_RE = /\A((?:\\[bBrR]|\\[cC]\[\d+\])+)([A-Z][A-Za-z'’\-]*(?: [A-Za-z'’\-]+){0,2}):[ ]+/
  CODE_RE = /\A((?:\\[bBrR]|\\[cC]\[\d+\])+)/
  KEEP_FRAMES = 90          # a box this soon after the last one counts as "the same conversation"

  WOOD    = Color.new(110, 74, 44)
  WOOD_HI = Color.new(165, 120, 76)
  WOOD_LO = Color.new(58, 36, 20)
  TEXT    = Color.new(246, 234, 208)
  SHADOW  = Color.new(58, 36, 20)

  @last_name = nil
  @last_code = nil
  @last_frame = -9999

  # Returns [message without the name, name or nil]
  def self.split(message)
    if (m = NAME_RE.match(message))
      @last_name = m[2]
      @last_code = m[1].downcase
      return [m[1] + message[m[0].length..], m[2]]
    end
    code = CODE_RE.match(message)&.[](1)&.downcase
    if code && code == @last_code && Graphics.frame_count - @last_frame <= KEEP_FRAMES
      return [message, @last_name]
    end
    @last_name = @last_code = nil
    [message, nil]
  end

  def self.finished
    @last_frame = Graphics.frame_count
  end

  def self.create(msgwindow, name)
    return nil if !name || !msgwindow || msgwindow.disposed?
    probe = Bitmap.new(8, 8)
    pbSetSystemFont(probe)
    tw = probe.text_size(name).width
    probe.dispose
    w = tw + 28
    h = 32
    sprite = BitmapSprite.new(w, h, msgwindow.viewport)
    b = sprite.bitmap
    b.fill_rect(0, 0, w, h, WOOD_LO)
    b.fill_rect(2, 2, w - 4, h - 4, WOOD_HI)
    b.fill_rect(4, 4, w - 8, h - 8, WOOD)
    pbSetSystemFont(b)
    pbDrawTextPositions(b, [[name, w / 2, (h - 26) / 2 - 1, :center, TEXT, SHADOW]])
    sprite.x = msgwindow.x + 24
    sprite.y = (msgwindow.y > Graphics.height / 2) ? msgwindow.y - h + 6 : msgwindow.y + msgwindow.height - 6
    sprite.z = msgwindow.z + 1
    sprite
  end
end

# Prepended (not aliased) so it chains cleanly with other hooks on pbMessageDisplay.
module SpeakerTabHook
  def pbMessageDisplay(msgwindow, message, *args, &block)
    message, name = SpeakerTab.split(message.to_s)
    tab = nil
    tab = SpeakerTab.create(msgwindow, name) if name && msgwindow && !msgwindow.disposed?
    begin
      return super(msgwindow, message, *args, &block)
    ensure
      tab&.dispose
      SpeakerTab.finished
    end
  end
end
Object.prepend(SpeakerTabHook) unless Object.ancestors.include?(SpeakerTabHook)
