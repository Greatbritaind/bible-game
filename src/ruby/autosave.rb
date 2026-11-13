# Auto-save: the game saves by itself every few minutes and whenever the player enters a new map,
# but only at a safe moment (walking around on the map: no message, menu, battle or event running).
# The page can also ask for a save right away (low battery).
#
# Turning it off:
#  - Players: Options menu > Auto-Save > Off (remembered in their save).
#  - Game maker: name a switch "No Autosave" in RPG Maker. While it is ON there are no auto-saves
#    (for example from the Elite Four entrance until the end).
module RTJAutoSave
  INTERVAL = 180 # seconds between saves
  @last_time = nil
  @last_count = nil
  @last_map = nil
  @map_changed = false

  def self.player_off?
    $PokemonSystem && $PokemonSystem.instance_variable_get(:@rtj_autosave_off) == true
  end

  # The switch named "No Autosave" (any spelling of spaces, dashes and capitals), looked up once
  def self.switch_id
    return @switch_id unless @switch_id.nil?
    names = ($data_system.switches rescue nil) || []
    @switch_id = names.index { |n| n.to_s.downcase.gsub(/[^a-z]/, "") == "noautosave" } || false
  end

  def self.switch_off?
    id = switch_id
    id && $game_switches && $game_switches[id]
  end

  def self.install
    return unless defined?(MenuHandlers)
    MenuHandlers.add(:options_menu, :rtj_autosave, {
      "name"        => _INTL("Auto-Save"),
      "order"       => 85,
      "type"        => EnumOption,
      "parameters"  => [_INTL("On"), _INTL("Off")],
      "description" => _INTL("Choose whether the game saves by itself every few minutes."),
      "get_proc"    => proc { RTJAutoSave.player_off? ? 1 : 0 },
      "set_proc"    => proc { |value, _scene| $PokemonSystem.instance_variable_set(:@rtj_autosave_off, value == 1) }
    })
  rescue StandardError
    nil
  end

  def self.safe?
    return false unless defined?(Scene_Map) && $scene.is_a?(Scene_Map)
    return false unless $game_temp && $game_player && $game_map && $game_system && $player && $PokemonGlobal
    return false if $game_temp.in_menu || $game_temp.in_battle || $game_temp.message_window_showing
    return false if $game_temp.player_transferring
    return false if $game_temp.respond_to?(:transition_processing) && $game_temp.transition_processing
    return false if $game_player.moving? || $game_player.move_route_forcing
    return false if $game_system.map_interpreter.running?
    return false if defined?(pbMapInterpreterRunning?) && pbMapInterpreterRunning?
    true
  end

  # Called twice a second from Graphics.update
  def self.tick(transitioning)
    return unless defined?(Game) && Game.respond_to?(:save) && $game_system
    now = Time.now.to_f
    # any save (the menu's Save too) restarts the timer
    if @last_count != $game_system.save_count
      @last_count = $game_system.save_count
      @last_time = now
    end
    @last_time ||= now
    map = $game_map&.map_id
    @map_changed = true if @last_map && map && map != @last_map
    @last_map = map if map
    urgent = RGSSRuntime.call(:save_now_requested).to_i == 1
    @urgent ||= urgent
    due = @map_changed || @urgent || now - @last_time >= INTERVAL
    return unless due
    if player_off? || switch_off?
      # turned off: forget what was waiting, and count the time from when it comes back on
      @map_changed = false
      @urgent = false
      @last_time = now
      return
    end
    if transitioning || !safe?
      if $__debug && (@dbg = (@dbg || 0) + 1) % 10 == 1
        puts "[autosave] waiting: scene=#{$scene.class} menu=#{$game_temp&.in_menu} battle=#{$game_temp&.in_battle} msg=#{$game_temp&.message_window_showing} transfer=#{$game_temp&.player_transferring} moving=#{$game_player&.moving?} forcing=#{$game_player&.move_route_forcing} interp=#{$game_system.map_interpreter.running?} trans=#{transitioning}"
      end
      return
    end
    saved = Game.save
    puts "[autosave] #{saved ? 'saved' : 'failed'}#{@urgent ? ' (battery)' : ''}#{@map_changed ? ' (new map)' : ''}" if $__debug
    return unless saved
    @last_count = $game_system.save_count
    @last_time = now
    @map_changed = false
    @urgent = false
    RGSSRuntime.call(:sync_saves)
    RGSSRuntime.call(:autosaved)
  rescue StandardError => e
    puts "[autosave] #{e.class}: #{e.message}" if $__debug
    nil
  end
end
