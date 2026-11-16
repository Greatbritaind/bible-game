#===============================================================================
# Fly animation (FireRed / LeafGreen style)
# Taking off: the player holds up a Poké Ball, a bird pops out and flies away,
# the player turns around and hops, and the bird swoops in from the right,
# catches them and flies off to the upper left.
# Landing: the bird swoops in from the right carrying the player, drops them
# off and flies away.
#
# Pictures (in Graphics/Characters):
#   fly_ball_boy.png / fly_ball_girl.png  - player holding up a Poké Ball,
#                                           frames side by side (BALL_FRAMES)
#   fly_ride_boy.png / fly_ride_girl.png  - player on the bird, flying left,
#                                           frames side by side (RIDE_FRAMES);
#                                           the 1st frame is used
#   fly_bird.png                          - the bird alone, flying left
# If a girl picture is missing, the boy one is used. If a picture is missing,
# Fly works the normal Essentials way.
#===============================================================================
module FlyAnimation
  BALL_FRAMES = 5
  RIDE_FRAMES = 2
  # Player character number (from metadata) => picture name ending
  PICTURES = { 1 => "boy", 2 => "girl" }
  # How far below the player's feet the bottom of the bird (its shadow) sits.
  # Empty space under the bird in the picture is ignored automatically.
  RIDE_DROP = 4
  HOP = 14 # how high the player hops (pixels)
  # Where the raised Poké Ball is, from the player's feet (x, y), if it can't be
  # found in the picture. Normally it's found by its red color in the last frame.
  BALL_SPOT = [8, -26]

  def self.bitmap(kind)
    ending = PICTURES[$player.character_ID] || "boy"
    names = (kind == "bird") ? ["fly_bird"] : ["fly_#{kind}_#{ending}", "fly_#{kind}_boy", "fly_#{kind}"]
    names.each do |name|
      next unless pbResolveBitmap("Graphics/Characters/" + name)
      return RPG::Cache.load_bitmap("Graphics/Characters/", name)
    end
    nil
  end

  def self.ready?
    %w[ball ride bird].all? { |k| bitmap(k) }
  end

  # Waits while the map keeps moving. The block gets how far along it is (0 to 1).
  def self.wait(seconds)
    start = System.uptime
    loop do
      t = [(System.uptime - start) / seconds, 1.0].min
      yield t if block_given?
      @sprites.each do |s|
        next if s.disposed?
        pbDayNightTint(s) # same time-of-day shading as the map
        s.update
      end
      Graphics.update
      Input.update
      pbUpdateSceneMap
      break if t >= 1
    end
  end

  def self.hide_player(hide)
    $game_player.instance_variable_set(:@transparent, hide)
    follower = (FollowingPkmn.get_event rescue nil)
    follower&.instance_variable_set(:@opacity, hide ? 0 : 255)
  end

  def self.start
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = []
  end

  def self.finish
    @sprites&.each { |s| s.dispose unless s.disposed? }
    @sprites = []
    @viewport&.dispose
    @viewport = nil
  end

  def self.new_sprite
    s = Sprite.new(@viewport)
    @sprites << s
    s
  end

  # Rows of empty space at the bottom of a picture, so the drawing (not the
  # picture's edge) lines up with the player's feet
  def self.empty_rows(bmp)
    @empty_rows ||= {}
    return @empty_rows[bmp.object_id] if @empty_rows[bmp.object_id]
    rows = 0
    (bmp.height - 1).downto(0) do |y|
      break if (0...bmp.width).any? { |x| bmp.get_pixel(x, y).alpha > 0 }
      rows += 1
    end
    @empty_rows[bmp.object_id] = rows
  end

  def self.show_frame(sprite, bmp, frames, index, drop = 0)
    w = bmp.width / frames
    sprite.bitmap = bmp
    sprite.src_rect.set(index * w, 0, w, bmp.height)
    sprite.ox = w / 2
    sprite.oy = bmp.height - empty_rows(bmp) - drop
  end

  # The player's own walking picture, facing a direction (2 down, 8 up)
  def self.show_player_frame(sprite, direction)
    bmp = RPG::Cache.load_bitmap("Graphics/Characters/", $game_player.character_name)
    w = bmp.width / 4
    h = bmp.height / 4
    row = { 2 => 0, 4 => 1, 6 => 2, 8 => 3 }[direction] || 0
    sprite.bitmap = bmp
    sprite.src_rect.set(0, row * h, w, h)
    sprite.ox = w / 2
    sprite.oy = h
  end

  # Finds the red top of the Poké Ball in the last ball frame
  def self.ball_spot(ball)
    w = ball.width / BALL_FRAMES
    left = w * (BALL_FRAMES - 1)
    xs = []
    ys = []
    ball.height.times do |y|
      w.times do |x|
        c = ball.get_pixel(left + x, y)
        next unless c.alpha > 0 && c.red > 190 && c.green < 130 && c.blue < 130
        xs << x
        ys << y
      end
    end
    return BALL_SPOT if xs.empty?
    bottom = ball.height - empty_rows(ball)
    [(xs.sum / xs.length) - (w / 2), (ys.sum / ys.length) + 2 - bottom]
  end

  def self.make_shadow
    s = new_sprite
    bmp = Bitmap.new(20, 6)
    [[4, 0, 12], [1, 1, 18], [0, 2, 20], [0, 3, 20], [1, 4, 18], [4, 5, 12]].each do |x, y, w|
      bmp.fill_rect(x, y, w, 1, Color.new(0, 0, 0))
    end
    s.bitmap = bmp
    s.ox = 10
    s.oy = 3
    s.opacity = 110
    s
  end

  def self.ease_out(t); 1 - ((1 - t)**2); end
  def self.ease_in(t); t * t; end

  def self.take_off
    ball = bitmap("ball")
    ride = bitmap("ride")
    bird = bitmap("bird")
    return false unless ball && ride && bird
    start
    $game_player.turn_down
    wait(0.1)
    x = $game_player.screen_x
    y = $game_player.screen_y
    hide_player(true)
    # 1. hold up the Poké Ball
    player = new_sprite
    player.x = x
    player.y = y
    BALL_FRAMES.times do |i|
      show_frame(player, ball, BALL_FRAMES, i)
      pbSEPlay("Battle throw") if i == BALL_FRAMES - 1
      wait(0.12)
    end
    wait(0.25)
    # 2. the ball opens and the bird flies off to the upper left
    pbSEPlay("Battle recall")
    flyer = new_sprite
    show_frame(flyer, bird, 1, 0, RIDE_DROP)
    flyer.x = x
    flyer.y = y - 16
    flyer.flash(Color.new(255, 255, 255, 255), 12)
    wait(0.55) do |t|
      flyer.x = x - (x + bird.width) * ease_in(t)
      flyer.y = (y - 16) - (y + 16) * ease_in(t)
    end
    # 3. the player lowers the ball, still facing down
    show_player_frame(player, 2)
    wait(0.45)
    # 4. hop, and the bird swoops in from the right to catch them
    shadow = make_shadow
    shadow.x = x
    shadow.y = y - 1
    start_x = Graphics.width + (bird.width / 2)
    flyer.x = start_x
    flyer.y = y - HOP
    pbSEPlay("Fly")
    wait(0.45) do |t|
      player.y = y - (HOP * ease_out([t / 0.4, 1].min))
      flyer.x = start_x - ((start_x - x) * t)
    end
    # caught!
    player.visible = false
    show_frame(flyer, ride, RIDE_FRAMES, 0, RIDE_DROP)
    wait(0.6) do |t|
      flyer.x = x - (x + ride.width) * ease_in(t)
      flyer.y = (y - HOP) - (y + ride.height) * 0.5 * ease_in(t)
      shadow.x = flyer.x
      shadow.opacity = 110 * (1 - t)
    end
    wait(0.3)
    finish
    true
  rescue StandardError
    finish
    hide_player(false)
    false
  end

  def self.land
    ride = bitmap("ride")
    bird = bitmap("bird")
    return hide_player(false) unless ride && bird
    start
    hide_player(true)
    x = $game_player.screen_x
    y = $game_player.screen_y
    flyer = new_sprite
    show_frame(flyer, ride, RIDE_FRAMES, 0, RIDE_DROP)
    start_x = Graphics.width + (ride.width / 2)
    high = y - HOP - 70
    shadow = make_shadow
    shadow.y = y - 1
    pbSEPlay("Fly")
    # swoop in from the right with the player on board
    wait(0.7) do |t|
      e = ease_out(t)
      flyer.x = start_x - ((start_x - x) * e)
      flyer.y = high + ((y - HOP - high) * e)
      shadow.x = flyer.x
      shadow.opacity = 110 * t
    end
    # drop the player off; the bird glides on to the left and slows down
    player = new_sprite
    show_player_frame(player, 2)
    player.x = x
    player.y = y - HOP
    show_frame(flyer, bird, 1, 0, RIDE_DROP)
    shadow.x = x
    turn_x = x - 70
    turn_y = y - HOP - 24
    wait(0.5) do |t|
      player.y = (y - HOP) + (HOP * ease_in([t / 0.35, 1].min))
      flyer.x = x - ((x - turn_x) * ease_out(t))
      flyer.y = (y - HOP) - ((y - HOP - turn_y) * ease_out(t))
    end
    shadow.visible = false
    # the player holds up the Poké Ball...
    ball = bitmap("ball")
    if ball
      player.y = y
      BALL_FRAMES.times do |i|
        show_frame(player, ball, BALL_FRAMES, i)
        wait(0.08)
      end
    end
    # ...and the bird turns around, flies back and shrinks into it
    flyer.mirror = true
    spot = ball ? ball_spot(ball) : BALL_SPOT
    ball_x = x + spot[0]
    ball_y = y + spot[1]
    from_x = flyer.x
    from_y = flyer.y
    pbSEPlay("Battle recall")
    wait(0.55) do |t|
      e = ease_in(t)
      flyer.x = from_x + ((ball_x - from_x) * e)
      flyer.y = from_y + ((ball_y - from_y) * e)
      flyer.zoom_x = flyer.zoom_y = 1 - (0.95 * e)
      flyer.color = Color.new(255, 255, 255, 255 * e)
    end
    flyer.visible = false
    player.flash(Color.new(255, 255, 255, 200), 8)
    wait(0.3)
    # lower the ball
    if ball
      (BALL_FRAMES - 2).downto(0) do |i|
        show_frame(player, ball, BALL_FRAMES, i)
        wait(0.07)
      end
    end
    finish
    $game_player.turn_down
    hide_player(false)
  rescue StandardError
    finish
    hide_player(false)
  end
end

# Same as Essentials' Fly, but with the animation above in place of the
# "Pokémon used Fly!" picture.
def pbFlyToNewLocation(pkmn = nil, move = :FLY)
  return false if $game_temp.fly_destination.nil?
  pkmn = $player.get_pokemon_with_move(move) if !pkmn
  if !$DEBUG && !pkmn
    $game_temp.fly_destination = nil
    yield if block_given?
    return false
  end
  animated = FlyAnimation.ready? && FlyAnimation.take_off
  if !animated && (!pkmn || !pbHiddenMoveAnimation(pkmn))
    name = pkmn&.name || $player.name
    pbMessage(_INTL("{1} used {2}!", name, GameData::Move.get(move).name))
  end
  $stats.fly_count += 1
  pbFadeOutIn do
    pbSEPlay("Fly") unless animated
    $game_temp.player_new_map_id    = $game_temp.fly_destination[0]
    $game_temp.player_new_x         = $game_temp.fly_destination[1]
    $game_temp.player_new_y         = $game_temp.fly_destination[2]
    $game_temp.player_new_direction = 2
    $game_temp.fly_destination = nil
    pbDismountBike
    $scene.transfer_player
    $game_map.autoplay
    $game_map.refresh
    yield if block_given?
    pbWait(0.25)
  end
  FlyAnimation.land if animated
  pbEraseEscapePoint
  return true
end
