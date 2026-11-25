#===============================================================================
# RTJ Theme: first-century look for text boxes and menus.
#   Speech box  = Graphics/Windowskins/rtj_speech (a small scroll with rollers)
#   Menus       = Graphics/Windowskins/rtj_menu   (a wood-framed tablet)
#   Letters     = Graphics/Windowskins/rtj_letter (use \w[rtj_letter] in a line)
# Dark text becomes lamp-black ink with a parchment shadow.
#===============================================================================
module MessageConfig
  {
    DARK_TEXT_MAIN_COLOR:     Color.new(43, 33, 24),
    DARK_TEXT_SHADOW_COLOR:   Color.new(214, 194, 150),
    MALE_TEXT_MAIN_COLOR:     Color.new(40, 84, 160),
    MALE_TEXT_SHADOW_COLOR:   Color.new(200, 206, 200),
    FEMALE_TEXT_MAIN_COLOR:   Color.new(200, 24, 16),
    FEMALE_TEXT_SHADOW_COLOR: Color.new(226, 200, 170),
  }.each do |name, color|
    remove_const(name) if const_defined?(name, false)
    const_set(name, color)
  end

  RTJ_SPEECH = "Graphics/Windowskins/rtj_speech"
  RTJ_MENU   = "Graphics/Windowskins/rtj_menu"

  def self.pbGetSpeechFrame
    return pbResolveBitmap(RTJ_SPEECH) || pbDefaultSpeechFrame || ""
  end

  def self.pbGetSystemFrame
    return pbResolveBitmap(RTJ_MENU) || pbDefaultSystemFrame || ""
  end
end

# Text colors drawn by individual screens, to match the repainted pictures.
module RTJTheme
  INK        = Color.new(43, 33, 24)
  INK_SHADOW = Color.new(214, 194, 150)
  CREAM      = Color.new(246, 234, 208)
  CREAM_SHADOW = Color.new(40, 24, 12)

  def self.set(klass, name, color)
    return if !klass
    klass.send(:remove_const, name) if klass.const_defined?(name, false)
    klass.const_set(name, color)
  end

  def self.apply
    set(Battle::Scene, :MESSAGE_BASE_COLOR, INK)
    set(Battle::Scene, :MESSAGE_SHADOW_COLOR, INK_SHADOW)
    set(Battle::Scene::PokemonDataBox, :NAME_BASE_COLOR, INK)
    set(Battle::Scene::PokemonDataBox, :NAME_SHADOW_COLOR, INK_SHADOW)
    set(PokemonPartyPanel, :TEXT_BASE_COLOR, CREAM)
    set(PokemonPartyPanel, :TEXT_SHADOW_COLOR, CREAM_SHADOW)
    # Options: the chosen row in blue, the chosen setting in terracotta
    set(Window_PokemonOption, :SEL_NAME_BASE_COLOR, Color.new(40, 84, 160))
    set(Window_PokemonOption, :SEL_NAME_SHADOW_COLOR, Color.new(200, 206, 200))
    set(Window_PokemonOption, :SEL_VALUE_BASE_COLOR, Color.new(164, 83, 47))
    set(Window_PokemonOption, :SEL_VALUE_SHADOW_COLOR, Color.new(226, 200, 170))
  rescue NameError
    nil
  end
end
RTJTheme.apply

# The Pokédex is Ezra's Scroll.
module Settings
  def self.pokedex_names
    return [
      [_INTL("Ezra's Scroll"), 2],
      [_INTL("Johto Pokédex"), 1],
      _INTL("National Pokédex")
    ]
  end
end
MenuHandlers.each(:pause_menu) { |option, hash| hash["name"] = _INTL("Ezra's Scroll") if option == :pokedex }

# Continue / New Game screen: ink text on the new panels, and the game's own words.
module RTJTheme
  def self.apply_load
    set(PokemonLoadPanel, :TEXT_COLOR, INK)
    set(PokemonLoadPanel, :TEXT_SHADOW_COLOR, INK_SHADOW)
    set(PokemonLoadPanel, :MALE_TEXT_COLOR, Color.new(40, 84, 160))
    set(PokemonLoadPanel, :MALE_TEXT_SHADOW_COLOR, Color.new(200, 206, 200))
    set(PokemonLoadPanel, :FEMALE_TEXT_COLOR, Color.new(200, 24, 16))
    set(PokemonLoadPanel, :FEMALE_TEXT_SHADOW_COLOR, Color.new(226, 200, 170))
  rescue NameError
    nil
  end
end
RTJTheme.apply_load

module RTJLoadWords
  def pbDrawTextPositions(bitmap, textpos)
    textpos.each do |t|
      t[0] = _INTL("Seals:") if t[0] == _INTL("Badges:")
      t[0] = _INTL("Scroll:") if t[0] == _INTL("Pokédex:")
    end
    textpos[0][2] -= 3 if textpos.length == 1   # New Game / Options: center on the smaller panel
    super
  end
end
PokemonLoadPanel.prepend(RTJLoadWords) unless PokemonLoadPanel.ancestors.include?(RTJLoadWords)
