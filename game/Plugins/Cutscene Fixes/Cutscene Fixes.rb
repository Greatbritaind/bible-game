#===============================================================================
# Cutscene Fixes
# Following Pokemon EX stops every character from walking through the Pokémon
# that follows the player, even characters set to "Through". In a cutscene that
# made a character's move route wait forever (and the game looked frozen), e.g.
# Tova running off in Arbel Forest when the player stood right next to her.
# Characters with Through on can now pass the following Pokémon too.
#===============================================================================
class Game_Character
  alias __cutscenefix__passable? passable? unless method_defined?(:__cutscenefix__passable?)

  def passable?(x, y, d, strict = false)
    if @through && self != $game_player
      new_x = x + (d == 6 ? 1 : d == 4 ? -1 : 0)
      new_y = y + (d == 2 ? 1 : d == 8 ? -1 : 0)
      return self.map.valid?(new_x, new_y)
    end
    return __cutscenefix__passable?(x, y, d, strict)
  end
end

#===============================================================================
# Old saves in Arbel Forest
# Event 9 in Arbel Forest used to be Ruth the spice trader. Ezer the Zealot now
# uses that event, so a save that beat Ruth counted Ezer as beaten too: Ezer
# was missing and Tova could be walked past. Ezer and Tova are always beaten
# together, so if Tova has not been beaten, Ezer comes back.
#===============================================================================
class Game_Map
  alias __cutscenefix__update update unless method_defined?(:__cutscenefix__update)

  def update
    if @map_id == 84 && $game_self_switches[[84, 9, "A"]] && !$game_self_switches[[84, 16, "A"]]
      $game_self_switches[[84, 9, "A"]] = false
      @need_refresh = true
    end
    __cutscenefix__update
  end
end
