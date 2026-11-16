#===============================================================================
# HM Shortcuts
# Once the player has found an HM (the item), every Pokémon in the party that
# could learn that move can use it outside battle, without learning it:
#  - it shows up in that Pokémon's menu (Summary, Fly, Surf, Switch...)
#  - walking up to water, a tree, a boulder... uses that Pokémon
# The usual badge rules for field moves still apply. HM moves can still be
# taught, and a Pokémon can forget them like any other move.
#===============================================================================
module HMShortcuts
  # How long the field move banner (Surf, Fly, Cut...) takes: 1.0 = normal
  # Essentials speed, 0.5 = twice as fast
  BANNER_SPEED = 0.55

  # Field move => the HM item that unlocks it
  def self.hm_items
    @hm_items ||= begin
      list = {}
      GameData::Item.each { |item| list[item.move] = item.id if item.is_HM? && item.move }
      list
    end
  end

  def self.unlocked?(move)
    item = hm_items[move]
    !item.nil? && $bag && $bag.has?(item)
  end

  # Can this Pokémon use this HM outside battle without knowing it?
  def self.can_use?(pkmn, move)
    return false if !pkmn || pkmn.egg?
    unlocked?(move) && pkmn.compatible_with_move?(move)
  end

  # HMs to add to this Pokémon's menu (ones it doesn't already know)
  def self.extra_moves(pkmn)
    hm_items.keys.select do |move|
      HiddenMoveHandlers.hasHandler(move) && !pkmn.hasMove?(move) && can_use?(pkmn, move)
    end
  end
end

# Walking up to water, trees, boulders, waterfalls and using Fly from the
# Town Map all look for "a Pokémon with this move"
class Trainer
  alias rtj_hm_get_pokemon_with_move get_pokemon_with_move unless method_defined?(:rtj_hm_get_pokemon_with_move)
  def get_pokemon_with_move(move)
    ret = rtj_hm_get_pokemon_with_move(move)
    return ret if ret || !HMShortcuts.hm_items[move]
    pokemon_party.find { |pkmn| HMShortcuts.can_use?(pkmn, move) }
  end
end

# HM moves can be forgotten like any other move
class Pokemon
  class Move
    def hidden_move?
      return false
    end
  end
end

# The party screen, with unlocked HMs added to each Pokémon's menu.
# (Following Pokemon EX wraps this screen, so replace the screen it wraps.)
class PokemonPartyScreen
  def rtj_hm_pokemon_screen
    can_access_storage = false
    if ($player.has_box_link || $bag.has?(:POKEMONBOXLINK)) &&
       !$game_switches[Settings::DISABLE_BOX_LINK_SWITCH] &&
       !$game_map.metadata&.has_flag?("DisableBoxLink")
      can_access_storage = true
    end
    @scene.pbStartScene(@party,
                        (@party.length > 1) ? _INTL("Choose a Pokémon.") : _INTL("Choose Pokémon or cancel."),
                        nil, false, can_access_storage)
    # Main loop
    loop do
      # Choose a Pokémon or cancel or press Action to quick switch
      @scene.pbSetHelpText((@party.length > 1) ? _INTL("Choose a Pokémon.") : _INTL("Choose Pokémon or cancel."))
      party_idx = @scene.pbChoosePokemon(false, -1, 1)
      break if (party_idx.is_a?(Numeric) && party_idx < 0) || (party_idx.is_a?(Array) && party_idx[1] < 0)
      # Quick switch
      if party_idx.is_a?(Array) && party_idx[0] == 1   # Switch
        @scene.pbSetHelpText(_INTL("Move to where?"))
        old_party_idx = party_idx[1]
        party_idx = @scene.pbChoosePokemon(true, -1, 2)
        pbSwitch(old_party_idx, party_idx) if party_idx >= 0 && party_idx != old_party_idx
        next
      end
      # Chose a Pokémon
      pkmn = @party[party_idx]
      # Get all commands
      command_list = []
      commands = []
      MenuHandlers.each_available(:party_menu, self, @party, party_idx) do |option, hash, name|
        command_list.push(name)
        commands.push(hash)
      end
      command_list.push(_INTL("Cancel"))
      # Add field move commands
      if !pkmn.egg?
        insert_index = ($DEBUG) ? 2 : 1
        pkmn.moves.each_with_index do |move, i|
          next if !HiddenMoveHandlers.hasHandler(move.id) &&
                  ![:MILKDRINK, :SOFTBOILED].include?(move.id)
          command_list.insert(insert_index, [move.name, 1])
          commands.insert(insert_index, i)
          insert_index += 1
        end
        # HMs this Pokémon could learn, once the player has found the HM
        HMShortcuts.extra_moves(pkmn).each do |move_id|
          command_list.insert(insert_index, [GameData::Move.get(move_id).name, 1])
          commands.insert(insert_index, move_id)
          insert_index += 1
        end
      end
      # Choose a menu option
      choice = @scene.pbShowCommands(_INTL("Do what with {1}?", pkmn.name), command_list)
      next if choice < 0 || choice >= commands.length
      # Effect of chosen menu option
      case commands[choice]
      when Hash   # Option defined via a MenuHandler below
        commands[choice]["effect"].call(self, @party, party_idx)
      when Integer, Symbol   # Hidden move's index, or an HM it doesn't need to know
        move = commands[choice].is_a?(Symbol) ? Pokemon::Move.new(commands[choice]) : pkmn.moves[commands[choice]]
        if [:MILKDRINK, :SOFTBOILED].include?(move.id)
          amt = [(pkmn.totalhp / 5).floor, 1].max
          if pkmn.hp <= amt
            pbDisplay(_INTL("Not enough HP..."))
            next
          end
          @scene.pbSetHelpText(_INTL("Use on which Pokémon?"))
          old_party_idx = party_idx
          loop do
            @scene.pbPreSelect(old_party_idx)
            party_idx = @scene.pbChoosePokemon(true, party_idx)
            break if party_idx < 0
            newpkmn = @party[party_idx]
            movename = move.name
            if party_idx == old_party_idx
              pbDisplay(_INTL("{1} can't use {2} on itself!", pkmn.name, movename))
            elsif newpkmn.egg?
              pbDisplay(_INTL("{1} can't be used on an Egg!", movename))
            elsif newpkmn.fainted? || newpkmn.hp == newpkmn.totalhp
              pbDisplay(_INTL("{1} can't be used on that Pokémon.", movename))
            else
              pkmn.hp -= amt
              hpgain = pbItemRestoreHP(newpkmn, amt)
              @scene.pbDisplay(_INTL("{1}'s HP was restored by {2} points.", newpkmn.name, hpgain))
              pbRefresh
            end
            break if pkmn.hp <= amt
          end
          @scene.pbSelect(old_party_idx)
          pbRefresh
        elsif pbCanUseHiddenMove?(pkmn, move.id)
          if pbConfirmUseHiddenMove(pkmn, move.id)
            @scene.pbEndScene
            if move.id == :FLY
              scene = PokemonRegionMap_Scene.new(-1, false)
              screen = PokemonRegionMapScreen.new(scene)
              ret = screen.pbStartFlyScreen
              if ret
                $game_temp.fly_destination = ret
                return [pkmn, move.id]
              end
              @scene.pbStartScene(
                @party, (@party.length > 1) ? _INTL("Choose a Pokémon.") : _INTL("Choose Pokémon or cancel.")
              )
              next
            end
            return [pkmn, move.id]
          end
        end
      end
    end
    @scene.pbEndScene
    return nil
  end

  if method_defined?(:__followingpkmn__pbPokemonScreen)
    alias __followingpkmn__pbPokemonScreen rtj_hm_pokemon_screen
  else
    alias pbPokemonScreen rtj_hm_pokemon_screen
  end
end

# The field move banner (the Pokémon sliding across the orange strip), with its
# speed set by HMShortcuts::BANNER_SPEED
def pbHiddenMoveAnimation(pokemon)
  speed = HMShortcuts::BANNER_SPEED
  return false if !pokemon
  viewport = Viewport.new(0, 0, Graphics.width, 0)
  viewport.z = 99999
  # Set up sprites
  bg = Sprite.new(viewport)
  bg.bitmap = RPG::Cache.ui("Field move/bg")
  sprite = PokemonSprite.new(viewport)
  sprite.setOffset(PictureOrigin::CENTER)
  sprite.setPokemonBitmap(pokemon)
  sprite.x = Graphics.width + (sprite.bitmap.width / 2)
  sprite.y = bg.bitmap.height / 2
  sprite.z = 1
  sprite.visible = false
  strobebitmap = AnimatedBitmap.new("Graphics/UI/Field move/strobes")
  strobes = []
  strobes_start_x = []
  strobes_timers = []
  15.times do |i|
    strobe = BitmapSprite.new(52, 16, viewport)
    strobe.bitmap.blt(0, 0, strobebitmap.bitmap, Rect.new(0, (i % 2) * 16, 52, 16))
    strobe.z = (i.even? ? 2 : 0)
    strobe.visible = false
    strobes.push(strobe)
  end
  strobebitmap.dispose
  # Do the animation
  phase = 1
  timer_start = System.uptime
  loop do
    Graphics.update
    Input.update
    sprite.update
    case phase
    when 1   # Expand viewport height from zero to full
      viewport.rect.y = lerp(Graphics.height / 2, (Graphics.height - bg.bitmap.height) / 2,
                             0.25 * speed, timer_start, System.uptime)
      viewport.rect.height = Graphics.height - (viewport.rect.y * 2)
      bg.oy = (bg.bitmap.height - viewport.rect.height) / 2
      if viewport.rect.y == (Graphics.height - bg.bitmap.height) / 2
        phase = 2
        sprite.visible = true
        timer_start = System.uptime
      end
    when 2   # Slide Pokémon sprite in from right to centre
      sprite.x = lerp(Graphics.width + (sprite.bitmap.width / 2), Graphics.width / 2,
                      0.4 * speed, timer_start, System.uptime)
      if sprite.x == Graphics.width / 2
        phase = 3
        pokemon.play_cry
        timer_start = System.uptime
      end
    when 3   # Wait
      if System.uptime - timer_start >= 0.75 * speed
        phase = 4
        timer_start = System.uptime
      end
    when 4   # Slide Pokémon sprite off from centre to left
      sprite.x = lerp(Graphics.width / 2, -(sprite.bitmap.width / 2),
                      0.4 * speed, timer_start, System.uptime)
      if sprite.x == -(sprite.bitmap.width / 2)
        phase = 5
        sprite.visible = false
        timer_start = System.uptime
      end
    when 5   # Shrink viewport height from full to zero
      viewport.rect.y = lerp((Graphics.height - bg.bitmap.height) / 2, Graphics.height / 2,
                             0.25 * speed, timer_start, System.uptime)
      viewport.rect.height = Graphics.height - (viewport.rect.y * 2)
      bg.oy = (bg.bitmap.height - viewport.rect.height) / 2
      phase = 6 if viewport.rect.y == Graphics.height / 2
    end
    # Constantly stream the strobes across the screen
    strobes.each_with_index do |strobe, i|
      strobe.ox = strobe.viewport.rect.x
      strobe.oy = strobe.viewport.rect.y
      if !strobe.visible   # Initial placement of strobes
        randomY = 16 * (1 + rand((bg.bitmap.height / 16) - 2))
        strobe.y = randomY + ((Graphics.height - bg.bitmap.height) / 2)
        strobe.x = rand(Graphics.width)
        strobe.visible = true
        strobes_start_x[i] = strobe.x
        strobes_timers[i] = System.uptime
      elsif strobe.x < Graphics.width   # Move strobe right
        strobe.x = strobes_start_x[i] + lerp(0, Graphics.width * 2, 0.8 * speed, strobes_timers[i], System.uptime)
      else   # Strobe is off the screen, reposition it to the left of the screen
        randomY = 16 * (1 + rand((bg.bitmap.height / 16) - 2))
        strobe.y = randomY + ((Graphics.height - bg.bitmap.height) / 2)
        strobe.x = -strobe.bitmap.width - rand(Graphics.width / 4)
        strobes_start_x[i] = strobe.x
        strobes_timers[i] = System.uptime
      end
    end
    pbUpdateSceneMap
    break if phase == 6
  end
  sprite.dispose
  strobes.each { |strobe| strobe.dispose }
  strobes.clear
  bg.dispose
  viewport.dispose
  return true
end
