#===============================================================================
# Item Pictures
# When the player finds or is given an item, a big picture of it is shown above
# the message, so players can see what they got without reading.
#===============================================================================
module ItemPicture
  ZOOM = 2   # item icons are 48 x 48; shown twice as big
  BOX  = 116 # size of the picture's frame

  def self.show(item)
    data = GameData::Item.try_get(item)
    return nil unless data
    file = GameData::Item.icon_filename(data.id)
    return nil if file.nil? || file.end_with?("/000") || file.end_with?("/back") || !pbResolveBitmap(file)
    viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    viewport.z = 99999
    x = (Graphics.width - BOX) / 2
    y = Graphics.height - 96 - BOX - 10
    frame = Sprite.new(viewport)
    frame.bitmap = Bitmap.new(BOX, BOX)
    frame.bitmap.fill_rect(0, 0, BOX, BOX, Color.new(40, 48, 72))          # dark border
    frame.bitmap.fill_rect(3, 3, BOX - 6, BOX - 6, Color.new(248, 240, 216)) # parchment
    frame.x = x
    frame.y = y
    icon = Sprite.new(viewport)
    icon.bitmap = RPG::Cache.load_bitmap("", file)
    icon.zoom_x = icon.zoom_y = ZOOM
    icon.x = x + ((BOX - (icon.bitmap.width * ZOOM)) / 2)
    icon.y = y + ((BOX - (icon.bitmap.height * ZOOM)) / 2)
    [viewport, frame, icon]
  rescue StandardError
    nil
  end

  def self.hide(shown)
    return unless shown
    viewport, frame, icon = shown
    frame.bitmap&.dispose
    frame.dispose
    icon.dispose
    viewport.dispose
  rescue StandardError
    nil
  end
end

# Items found on the ground (item balls)
alias rtj_pictures_pbItemBall pbItemBall unless defined?(rtj_pictures_pbItemBall)
def pbItemBall(item, quantity = 1)
  shown = ItemPicture.show(item)
  rtj_pictures_pbItemBall(item, quantity)
ensure
  ItemPicture.hide(shown)
end

# Items given by people
alias rtj_pictures_pbReceiveItem pbReceiveItem unless defined?(rtj_pictures_pbReceiveItem)
def pbReceiveItem(item, quantity = 1)
  shown = ItemPicture.show(item)
  rtj_pictures_pbReceiveItem(item, quantity)
ensure
  ItemPicture.hide(shown)
end
