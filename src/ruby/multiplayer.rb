# Class sessions (multiplayer): classmates who joined the same class code can see each other walk
# around. They are only pictures: they walk through everything, never start events, battles or
# cutscenes, and nothing about them goes into anyone's save. The page (mp.ts) talks to the server;
# this file sends where the player is and draws the classmates on the same map.
module RTJMP
  NAME_W = 112

  # A classmate on this map: a character that walks toward wherever the classmate is now.
  # Built after the game's scripts load (it needs Game_Character).
  def self.define_ghost
    return if const_defined?(:Ghost, false)
    const_set(:Ghost, Class.new(Game_Character) do
      attr_accessor :target, :tdir, :label
      def initialize(map)
        super(map)
        @through = true
        @walk_anime = true
        @step_anime = false
        @move_speed = 4
        @target = nil
        @tdir = 2
      end

      def graphic=(name)
        @character_name = name
      end

      def can_move_in_direction?(*) = true
      def passable?(*) = true
      def check_event_trigger_touch(*) = false
      def increase_steps; end

      def update
        super
        return if moving? || !@target
        tx, ty = @target
        dx = tx - @x
        dy = ty - @y
        if dx.abs + dy.abs > 5
          moveto(tx, ty)
          @direction = @tdir
        elsif dx != 0 || dy != 0
          @move_speed = (dx.abs + dy.abs > 2) ? 5 : 4
          if dx.abs >= dy.abs then (dx > 0 ? move_right : move_left)
          else (dy > 0 ? move_down : move_up)
          end
        elsif @direction != @tdir
          @direction = @tdir
        end
      end
    end)
  end

  @ghosts = {}       # uid => Ghost
  @sprites = {}      # uid => [Sprite_Character, name sprite]
  @last = nil
  @map_id = nil
  @frame = 0
  @active = false

  class << self
    attr_reader :ghosts, :ready
  end

  def self.on_map?
    defined?(Scene_Map) && $scene.is_a?(Scene_Map) && $game_map && $game_player && $player && !($game_temp && $game_temp.in_battle)
  end

  # The player's map, tile, facing and look, sent whenever one of them changes
  def self.state
    name = $player.name.to_s.gsub(/[|\n]/, " ")[0, 16]
    place = ($game_map.name rescue "").to_s.gsub(/[|\n]/, " ")[0, 32]
    [$game_map.map_id, $game_player.x, $game_player.y, $game_player.direction,
     $game_player.character_name.to_s.gsub(/[|\n]/, ""), name, place].join("|")
  end

  def self.update
    @frame += 1
    @active = RGSSRuntime.call(:mp_active).to_i == 1 if @frame % 30 == 1
    unless @active
      clear unless @ghosts.empty?
      @last = nil
      return
    end
    return unless on_map?
    clear if @map_id != $game_map.map_id
    @map_id = $game_map.map_id
    s = state
    if s != @last
      @last = s
      RGSSRuntime.call(:mp_send, s)
    end
    receive if @frame % 3 == 0
    @ghosts.each_value(&:update)
    update_sprites
  rescue StandardError => e
    puts "[mp] #{e.class}: #{e.message} #{e.backtrace&.first}" if $__debug
  end

  # One line per classmate on this map: uid|name|x|y|direction|character graphic
  def self.receive
    text = RGSSRuntime.call(:mp_read).to_s
    return if text == "~"
    seen = {}
    text.each_line do |line|
      uid, name, x, y, d, gfx = line.chomp.split("|", 6)
      next if uid.nil? || uid.empty? || gfx.nil?
      seen[uid] = true
      g = @ghosts[uid]
      unless g
        g = Ghost.new($game_map)
        g.moveto(x.to_i, y.to_i)
        @ghosts[uid] = g
      end
      g.graphic = gfx unless gfx.empty?
      g.target = [x.to_i, y.to_i]
      g.tdir = [2, 4, 6, 8].include?(d.to_i) ? d.to_i : 2
      g.label = name
    end
    (@ghosts.keys - seen.keys).each { |uid| remove(uid) }
  end

  def self.update_sprites
    vp = Spriteset_Map.viewport
    @ghosts.each do |uid, g|
      sp, tag = @sprites[uid]
      if sp.nil? || sp.disposed?
        sp = Sprite_Character.new(vp, g)
        tag = Sprite.new(vp)
        tag.bitmap = Bitmap.new(NAME_W, 20)
        tag.instance_variable_set(:@label, nil)
        @sprites[uid] = [sp, tag]
      end
      sp.update
      if tag.instance_variable_get(:@label) != g.label
        tag.instance_variable_set(:@label, g.label)
        b = tag.bitmap
        b.clear
        b.font.size = 16
        b.font.bold = true
        b.font.color = Color.new(40, 40, 48)
        [[-1, 0], [1, 0], [0, -1], [0, 1]].each { |ox, oy| b.draw_text(ox, 2 + oy, NAME_W, 16, g.label.to_s, 1) }
        b.font.color = Color.new(255, 255, 255)
        b.draw_text(0, 2, NAME_W, 16, g.label.to_s, 1)
      end
      tag.x = g.screen_x - NAME_W / 2
      tag.y = g.screen_y - 70
      tag.z = 3500
      tag.visible = sp.visible
    end
  end

  def self.remove(uid)
    @ghosts.delete(uid)
    sp, tag = @sprites.delete(uid)
    sp&.dispose
    if tag
      tag.bitmap&.dispose
      tag.dispose
    end
  end

  def self.clear
    @ghosts.keys.each { |uid| remove(uid) }
  end

  def self.install
    return unless defined?(Scene_Map) && defined?(Game_Character)
    define_ghost
    @ready = true
  rescue StandardError => e
    puts "[mp] install: #{e.message}" if $__debug
  end
end
