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
