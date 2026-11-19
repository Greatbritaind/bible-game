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
