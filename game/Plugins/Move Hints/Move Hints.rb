#===============================================================================
# Move Hints: in the Fight menu, a move's name turns green when it's super
# effective on the foe and red when it's not very effective. Moves with no
# effect turn grey. Status moves and normal hits keep their usual color.
# Uses the type chart only (no hidden abilities). Can be turned off in Options.
#===============================================================================
module MoveHints
  STRONG  = Color.new(24, 140, 40)
  WEAK    = Color.new(200, 30, 30)
  NO_EFFECT = Color.new(130, 130, 130)

  def self.on?
    return ($PokemonSystem&.move_hints || 0) == 0
  end

  # The foe this move would hit: the first one still standing.
  def self.target_for(user)
    user.eachOpposing { |b| return b if b && !b.fainted? }
    return nil
  rescue StandardError
    return nil
  end

  def self.color_for(move, user)
    return nil if !on? || !move || move.statusMove?
    foe = target_for(user)
    return nil if !foe
    type = move.display_type(user) || move.type
    return nil if !type
    value = Effectiveness.calculate(type, *foe.pbTypes(true))
    return NO_EFFECT if Effectiveness.ineffective?(value)
    return STRONG if Effectiveness.super_effective?(value)
    return WEAK if Effectiveness.not_very_effective?(value)
    return nil
  rescue StandardError
    return nil
  end
end

class PokemonSystem
  attr_writer :move_hints
  def move_hints
    return @move_hints || 0   # 0 = On (old saves start with it on)
  end
end

MenuHandlers.add(:options_menu, :move_hints, {
  "name"        => _INTL("Move Hints"),
  "order"       => 55,
  "type"        => EnumOption,
  "parameters"  => [_INTL("On"), _INTL("Off")],
  "description" => _INTL("Green moves are strong. Red moves are weak."),
  "get_proc"    => proc { next $PokemonSystem.move_hints },
  "set_proc"    => proc { |value, _scene| $PokemonSystem.move_hints = value }
})

module MoveHintsFightMenu
  def refreshButtonNames
    super
    return if !Battle::Scene::FightMenu::USE_GRAPHICS || !@battler || !@overlay
    moves = @battler.moves
    return if moves.none? { |m| MoveHints.color_for(m, @battler) }
    # Redraw the names, recoloring the strong / weak ones.
    @overlay.bitmap.clear
    textPos = []
    @buttons.each_with_index do |button, i|
      next if !@visibility["button_#{i}"] || !moves[i]
      x = button.x - self.x + (button.src_rect.width / 2)
      y = button.y - self.y + 14
      base = self.class::TEXT_BASE_COLOR
      if Battle::Scene::FightMenu::GET_MOVE_TEXT_COLOR_FROM_MOVE_BUTTON && moves[i].display_type(@battler)
        base = button.bitmap.get_pixel(10, button.src_rect.y + 34)
      end
      base = MoveHints.color_for(moves[i], @battler) || base
      textPos.push([moves[i].name, x, y, :center, base, self.class::TEXT_SHADOW_COLOR])
    end
    pbDrawTextPositions(@overlay.bitmap, textPos)
  end
end
Battle::Scene::FightMenu.prepend(MoveHintsFightMenu)
