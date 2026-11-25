#===============================================================================
# Witness Case (side quest)
# Ezra's case holds the things the player is given or finds after each miracle.
# The witness items are not bag items: the game remembers which ones were found.
#
#   pbAddWitness(:WEDDINGCUP)  - mark one found, show its picture and message
#   pbWitnessCount             - how many are found (used at the ending)
#   pbHasWitness?(:ROOFTILE)   - true if that one is found
#   pbWitnessCaseMenu          - the Witness Case screen (also opens from the Bag)
#
# Pictures: Graphics/Witness/<ID>.png (48 x 48)
#===============================================================================
module WitnessCase
  # id, name, description shown in the case
  ITEMS = [
    [:WEDDINGCUP,   "Wedding Cup",   "A cup from the stone jars. Water became wine. John 2:1-11"],
    [:ROOFTILE,     "Roof Tile",     "Friends dug through a roof for a man who couldn't walk. Mark 2:1-12"],
    [:SCROLLCLOTH,  "Scroll Cloth",  "It wrapped the Isaiah scroll the teacher read. Luke 4:16-21"],
    [:BURIALCLOTH,  "Burial Cloth",  "He won't need it now. Luke 7:11-17"],
    [:TORNNET,      "Torn Net",      "The nets were so full they tore. Luke 5:1-11"],
    [:WALKINGSTICK, "Walking Stick", "Bent for 18 years. Now she stands tall. Luke 13:10-17"],
    [:BROKENCHAIN,  "Broken Chain",  "No chain could hold him. Then he was free. Mark 5:1-20"],
    [:BARLEYLOAF,   "Barley Loaf",   "Five loaves fed thousands. John 6:1-14"],
    [:SILVERCOIN,   "Silver Coin",   "He paid back four times what he took. Luke 19:1-10"],
    [:PERFUMESHARD, "Perfume Shard", "A whole jar poured out for him. Mark 14:3-9"],
    [:FOLDEDLINEN,  "Folded Linen",  "Left folded in the empty tomb. John 20:6-7"]
  ]

  def self.data(id)
    ITEMS.find { |item| item[0] == id }
  end

  def self.picture_file(id)
    "Graphics/Witness/#{id}"
  end

  # Same parchment frame as the Item Pictures plugin, using the witness picture.
  def self.show_picture(id)
    file = picture_file(id)
    return nil unless pbResolveBitmap(file)
    box = ItemPicture::BOX
    zoom = ItemPicture::ZOOM
    viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    viewport.z = 99999
    x = (Graphics.width - box) / 2
    y = Graphics.height - 96 - box - 10
    frame = Sprite.new(viewport)
    frame.bitmap = Bitmap.new(box, box)
    frame.bitmap.fill_rect(0, 0, box, box, Color.new(40, 48, 72))
    frame.bitmap.fill_rect(3, 3, box - 6, box - 6, Color.new(248, 240, 216))
    frame.x = x
    frame.y = y
    icon = Sprite.new(viewport)
    icon.bitmap = RPG::Cache.load_bitmap("", file)
    icon.zoom_x = icon.zoom_y = zoom
    icon.x = x + ((box - (icon.bitmap.width * zoom)) / 2)
    icon.y = y + ((box - (icon.bitmap.height * zoom)) / 2)
    [viewport, frame, icon]
  rescue StandardError
    nil
  end

  def self.hide_picture(shown)
    ItemPicture.hide(shown)
  end
end

class Player
  def witnesses
    @witnesses ||= []
  end
end

def pbHasWitness?(id)
  $player.witnesses.include?(id)
end

def pbWitnessCount
  $player.witnesses.length
end

# Marks a witness item found and shows it. Before the player has the case,
# it is only "received"; after, it also goes into Ezra's case.
def pbAddWitness(id)
  data = WitnessCase.data(id)
  raise ArgumentError, "Unknown witness item #{id.inspect}" unless data
  return false if pbHasWitness?(id)
  $player.witnesses.push(id)
  shown = WitnessCase.show_picture(id)
  begin
    pbMessage("\\me[Key item get]" + _INTL("You received the \\c[1]{1}\\c[0]!", data[1]) + "\\wtnp[40]")
    pbMessage(_INTL("You put the {1} in Ezra's case.", data[1])) if $bag.has?(:WITNESSCASE)
  ensure
    WitnessCase.hide_picture(shown)
  end
  true
end

#===============================================================================
# The Witness Case screen: a parchment page with the list of 11 on the right,
# and the highlighted item's picture and description on the left.
# Up/Down scroll through the list. Back closes it.
#===============================================================================
class WitnessCaseScreen
  VISIBLE = 8                         # rows shown at once
  ROW_H   = 32
  LIST_X  = 256                       # list column
  LIST_Y  = 56
  INK     = Color.new(72, 48, 32)     # dark brown text
  INK_SH  = Color.new(208, 192, 160)  # its shadow
  FAINT   = Color.new(150, 130, 105)  # "???" rows
  PAPER   = Color.new(248, 240, 216)
  EDGE    = Color.new(40, 48, 72)
  ROWHI   = Color.new(232, 216, 176)  # highlighted row

  def initialize
    @index = 0
    @top = 0
  end

  def items = WitnessCase::ITEMS

  def run
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @page = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    pbSetSystemFont(@page.bitmap)
    @icon = Sprite.new(@viewport)
    @icon.zoom_x = @icon.zoom_y = 2
    refresh
    pbFadeInAndShow({ "page" => @page, "icon" => @icon }) { update_frame }
    loop do
      update_frame
      if Input.repeat?(Input::DOWN) && @index < items.length - 1
        @index += 1
        pbPlayCursorSE
        refresh
      elsif Input.repeat?(Input::UP) && @index > 0
        @index -= 1
        pbPlayCursorSE
        refresh
      elsif Input.trigger?(Input::BACK)
        pbPlayCloseMenuSE
        break
      end
    end
    pbFadeOutAndHide({ "page" => @page, "icon" => @icon }) { update_frame }
  ensure
    @icon&.bitmap = nil
    @icon&.dispose
    @page&.dispose
    @viewport&.dispose
  end

  def update_frame
    Graphics.update
    Input.update
  end

  def refresh
    @top = @index if @index < @top
    @top = @index - VISIBLE + 1 if @index >= @top + VISIBLE
    b = @page.bitmap
    b.clear
    w, h = Graphics.width, Graphics.height
    b.fill_rect(0, 0, w, h, EDGE)
    b.fill_rect(4, 4, w - 8, h - 8, PAPER)
    text = []
    text.push([_INTL("Ezra's Case"), 20, 14, :left, INK, INK_SH])
    text.push([_INTL("{1} of {2} found", pbWitnessCount, items.length), w - 20, 14, :right, INK, INK_SH])
    b.fill_rect(16, 46, w - 32, 2, INK)
    # the list
    VISIBLE.times do |row|
      i = @top + row
      break if i >= items.length
      id, name, _ = items[i]
      y = LIST_Y + (row * ROW_H)
      b.fill_rect(LIST_X - 8, y, w - LIST_X - 8, ROW_H - 2, ROWHI) if i == @index
      found = pbHasWitness?(id)
      text.push([(i == @index ? "> " : "  ") + (found ? name : "???"), LIST_X, y + 4, :left, found ? INK : FAINT, found ? INK_SH : nil])
    end
    # scroll arrows when there are more rows above or below
    text.push(["^", w - 28, LIST_Y - 10, :left, INK, nil]) if @top > 0
    text.push(["v", w - 28, LIST_Y + (VISIBLE * ROW_H) - 14, :left, INK, nil]) if @top + VISIBLE < items.length
    # the picture frame
    fx, fy, box = 40, 64, 120
    b.fill_rect(fx, fy, box, box, EDGE)
    b.fill_rect(fx + 3, fy + 3, box - 6, box - 6, Color.new(255, 250, 236))
    pbDrawTextPositions(b, text)
    id, name, desc = items[@index]
    if pbHasWitness?(id) && pbResolveBitmap(WitnessCase.picture_file(id))
      @icon.bitmap = RPG::Cache.load_bitmap("", WitnessCase.picture_file(id))
      @icon.x = fx + ((box - (@icon.bitmap.width * 2)) / 2)
      @icon.y = fy + ((box - (@icon.bitmap.height * 2)) / 2)
      @icon.visible = true
      body = desc
    else
      @icon.visible = false
      pbDrawTextPositions(b, [["?", fx + (box / 2), fy + (box / 2) - 14, :center, FAINT, nil]])
      body = _INTL("You haven't found this one yet.")
    end
    # description under the picture, down the left side
    drawTextEx(b, 20, fy + box + 14, LIST_X - 44, 4, body, INK, INK_SH)
  end
end

def pbWitnessCaseMenu
  WitnessCaseScreen.new.run
end

ItemHandlers::UseFromBag.add(:WITNESSCASE, proc { |item|
  pbWitnessCaseMenu
  next 1
})

ItemHandlers::UseInField.add(:WITNESSCASE, proc { |item|
  pbWitnessCaseMenu
  next true
})

#===============================================================================
# The messenger who brings the case. He shows up out of sight, about 8 steps
# away, and runs to the player wherever they are standing, then runs back.
#===============================================================================
module WitnessCase
  DIRS = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }
  STEP = { 2 => PBMoveRoute::DOWN, 4 => PBMoveRoute::LEFT, 6 => PBMoveRoute::RIGHT, 8 => PBMoveRoute::UP }
  BACK = { 2 => 8, 4 => 6, 6 => 4, 8 => 2 }

  # Walkable tiles out from the player; returns the steps from a far tile back to
  # the tile next to the player.
  def self.approach_path(event, dist)
    start = [$game_player.x, $game_player.y]
    came = { start => nil }
    depth = { start => 0 }
    queue = [start]
    far = start
    until queue.empty?
      cur = queue.shift
      far = cur if depth[cur] > depth[far]
      break if depth[cur] >= dist
      DIRS.each do |d, (dx, dy)|
        nxt = [cur[0] + dx, cur[1] + dy]
        next if came.key?(nxt) || !$game_map.valid?(nxt[0], nxt[1])
        next unless event.passable?(cur[0], cur[1], d)
        came[nxt] = [cur, d]
        depth[nxt] = depth[cur] + 1
        queue.push(nxt)
      end
    end
    steps = []   # directions to walk from `far` toward the player
    node = far
    while came[node]
      prev, d = came[node]
      steps.push(BACK[d])
      node = prev
    end
    steps.pop    # stop next to the player, not on top of them
    [far, steps]
  end

  def self.run(event, dirs)
    return if dirs.empty?
    pbMoveRoute(event, [PBMoveRoute::THROUGH_ON] + dirs.map { |d| STEP[d] })
    loop do
      Graphics.update
      Input.update
      pbUpdateSceneMap
      break unless event.move_route_forcing
    end
  end
end

def pbWitnessMessengerArrive(event, dist = 8)
  far, steps = WitnessCase.approach_path(event, dist)
  event.moveto(far[0], far[1])
  $game_temp.instance_variable_set(:@witness_messenger_path, steps)
  WitnessCase.run(event, steps)
  event.turn_toward_player
  $game_player.turn_generic(10 - event.direction)
end

def pbWitnessMessengerLeave(event)
  steps = $game_temp.instance_variable_get(:@witness_messenger_path) || []
  WitnessCase.run(event, steps.reverse.map { |d| WitnessCase::BACK[d] } + [steps.empty? ? 2 : WitnessCase::BACK[steps.last]])
end
