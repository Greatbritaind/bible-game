#===============================================================================
# Secret Grass: a patch of grass with its own wild Pokémon, inside a normal map.
#
# How to use:
#  1. Draw the patch with normal tall grass.
#  2. Make an event over the patch named   SecretGrass size(W,H)
#     W = how many tiles wide, H = how many tiles tall. Put the event on the
#     patch's BOTTOM-LEFT tile (that's how size(W,H) events are measured).
#     No graphic, no commands. Options: tick "Through". Priority: below characters.
#  3. In PBS/encounters.txt, add a "Secret" list for that map, under its Land list:
#        [085] # Route 2
#        Land,21
#            30,PIDGEY,3,5
#        Secret,21
#            60,ABRA,6,8
#            40,PIKACHU,6,8
#     (21 is how often a step finds a Pokémon, like Land. Day/Night versions
#     also work: SecretDay, SecretNight, SecretMorning, ...)
#
# Walking in grass inside the event's area uses the Secret list. Everywhere else
# on the map uses the normal Land list. A map can have several SecretGrass events.
#===============================================================================
%w[Secret SecretDay SecretNight SecretMorning SecretAfternoon SecretEvening].each do |name|
  GameData::EncounterType.register({
    :id             => name.to_sym,
    :type           => :land,
    :trigger_chance => 21
  })
end

module SecretGrass
  # Is (x, y) inside a SecretGrass event's area on the current map?
  def self.at?(x, y)
    return false if !$game_map
    $game_map.events.each_value do |ev|
      next if !ev.name[/SecretGrass/i]
      return true if ev.at_coordinate?(x, y)
    end
    false
  end
end

class PokemonEncounters
  alias __secretgrass__encounter_type encounter_type unless method_defined?(:__secretgrass__encounter_type)

  def encounter_type
    if !$PokemonGlobal.surfing && has_encounter_type_family?(:Secret) &&
       $game_map.terrain_tag($game_player.x, $game_player.y).land_wild_encounters &&
       SecretGrass.at?($game_player.x, $game_player.y)
      ret = find_valid_encounter_type_for_time(:Secret, pbGetTimeNow)
      return ret if ret
    end
    __secretgrass__encounter_type
  end

  # True if the map has :Secret or any of its time-of-day versions
  def has_encounter_type_family?(base)
    ["", "Day", "Night", "Morning", "Afternoon", "Evening"].any? { |s| has_encounter_type?((base.to_s + s).to_sym) }
  end
end
