#===============================================================================
# Fly animation (FireRed / LeafGreen style)
# When the player flies: they hold up a Poké Ball, hop onto a bird, and fly up
# off the screen. At the new town the bird swoops down and drops them off.
#
# Pictures (in Graphics/Characters):
#   fly_ball_boy.png  / fly_ball_girl.png   - the player holding up a Poké Ball,
#                                             frames side by side (BALL_FRAMES)
#   fly_ride_boy.png  / fly_ride_girl.png   - the player on the bird, frames side
#                                             by side (RIDE_FRAMES): 1st = getting
#                                             on, 2nd = flying away
# If a girl picture is missing, the boy one is used. If none are found, Fly
# works the normal Essentials way.
#===============================================================================
module FlyAnimation
  BALL_FRAMES = 5
  RIDE_FRAMES = 2
  # Player character number (from metadata) => picture name ending
  PICTURES = { 1 => "boy", 2 => "girl" }
  # How far below the player's feet the bottom of the bird (its shadow) sits.
  # Empty space under the bird in the picture is ignored automatically.
  RIDE_DROP = 4

  def self.bitmap(kind)
    ending = PICTURES[$player.character_ID] || "boy"
    ["fly_#{kind}_#{ending}", "fly_#{kind}_boy", "fly_#{kind}"].each do |name|
      next unless pbResolveBitmap("Graphics/Characters/" + name)
      return RPG::Cache.load_bitmap("Graphics/Characters/", name)
    end
    nil
  end

  def self.ready?
    !bitmap("ball").nil? && !bitmap("ride").nil?
  end

  # Waits while the map keeps moving. The block gets how far along it is (0 to 1).
  def self.wait(seconds)
    start = System.uptime
    loop do
      t = [(System.uptime - start) / seconds, 1.0].min
      yield t if block_given?
      if @sprite
        pbDayNightTint(@sprite)   # same time-of-day shading as the map
        @sprite.update
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

  def self.make_sprite
    viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    viewport.z = 99999
    @sprite = Sprite.new(viewport)
    pbDayNightTint(@sprite)
    [viewport, @sprite]
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

  def self.take_off
    ball = bitmap("ball")
    ride = bitmap("ride")
    return false unless ball && ride
    $game_player.turn_down
    wait(0.1)
    viewport, sprite = make_sprite
    x = $game_player.screen_x
    y = $game_player.screen_y
    sprite.x = x
    sprite.y = y
    hide_player(true)
    # hold up the Poké Ball
    BALL_FRAMES.times do |i|
      show_frame(sprite, ball, BALL_FRAMES, i)
      pbSEPlay("Battle throw") if i == BALL_FRAMES - 1
      wait(0.12)
    end
    wait(0.3)
    # the ball opens and the bird appears
    pbSEPlay("Battle recall")
    show_frame(sprite, ride, RIDE_FRAMES, 0, RIDE_DROP)
    sprite.flash(Color.new(255, 255, 255, 255), 16)
    wait(0.6)
    # fly up and away
    pbSEPlay("Fly")
    show_frame(sprite, ride, RIDE_FRAMES, RIDE_FRAMES - 1, RIDE_DROP)
    distance = y + ride.height
    wait(0.8) { |t| sprite.y = y - (distance * t * t) }
    sprite.dispose
    viewport.dispose
    @sprite = nil
    true
  rescue StandardError
    @sprite = nil
    sprite&.dispose
    viewport&.dispose
    hide_player(false)
    false
  end

  def self.land
    ride = bitmap("ride")
    return hide_player(false) unless ride
    hide_player(true)
    viewport, sprite = make_sprite
    x = $game_player.screen_x
    y = $game_player.screen_y
    sprite.x = x
    show_frame(sprite, ride, RIDE_FRAMES, RIDE_FRAMES - 1, RIDE_DROP)
    start_y = -8
    pbSEPlay("Fly")
    wait(0.7) { |t| sprite.y = start_y + ((y - start_y) * (1 - ((1 - t)**2))) }
    show_frame(sprite, ride, RIDE_FRAMES, 0, RIDE_DROP)
    wait(0.35)
    sprite.dispose
    viewport.dispose
    @sprite = nil
    hide_player(false)
  rescue StandardError
    @sprite = nil
    sprite&.dispose
    viewport&.dispose
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
