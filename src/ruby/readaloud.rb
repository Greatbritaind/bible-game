# Read aloud: sends the text of message boxes (dialogue, signs, battle messages, yes/no questions) to the
# page, which speaks it when the player has read aloud turned on. Menus, names, HUDs and other on-screen
# text are never sent.
#
# Hooks are installed with Module#prepend just before the game's last script section runs, so they keep
# working when plugins (loaded later) redefine the same methods.
module ReadAloud
  @last_text = nil
  @last_frame = -1

  # Turns a message with Essentials control codes into plain words.
  def self.clean(message)
    t = message.to_s.dup
    t.gsub!(/\\\\/, "\5") # an escaped backslash
    t.gsub!(/\\n\[([1-8])\]/i) { $game_actors ? $game_actors[$1.to_i].name.to_s : "" }
    t.gsub!(/\\pn/i) { $player ? $player.name.to_s : "" }
    t.gsub!(/\\pm/i) { $player ? "$#{$player.money}" : "" }
    10.times do
      before = t.dup
      t.gsub!(/\\v\[([0-9]+)\]/i) { $game_variables ? $game_variables[$1.to_i].to_s : "" }
      break if t == before
    end
    # codes with a value: \c[2] \f[face] \se[sound] \w[skin] \ch[choices] ...
    t.gsub!(/\\(?:wtnp|sign|ff|ts|cl|me|se|wt|ch|c|f|w|l)\[[^\]]*\]/i, "")
    t.gsub!(/\\n/i, " ")                                         # line break
    t.gsub!(/\\(?:pog|pg|cn|pt|wd|wm|op|cl|wu|b|r|g)/i, "")     # codes without a value: \b \r \g \op ...
    t.gsub!(/\\[.|!^1]/, " ")                   # pauses and waits
    t.gsub!(/<\/?[a-z][a-z0-9]*(=[^>]*)?>/i, "") # text formatting tags: <c3=...> <b> <ac> ...
    t.tr!("\1\2\3\4", "    ")
    t.tr!("\5", "\\")
    t.gsub!(/\s+/, " ")
    t.strip
  end

  def self.say(message)
    text = clean(message)
    return if text.empty? || text !~ /[[:alnum:]]/
    frame = Graphics.frame_count
    # some methods are aliases of each other, so the same message can arrive twice at once
    return if text == @last_text && frame == @last_frame
    @last_text = text
    @last_frame = frame
    RGSSRuntime.call(:speak, text)
  rescue StandardError
    nil # reading aloud must never break the game
  end

  # Message boxes on the map and in menus all go through pbMessageDisplay
  module MessageHook
    def pbMessageDisplay(msgwindow, message, *args, &block)
      ReadAloud.say(message) if msgwindow
      super
    end
  end

  # Battles have their own message box
  module BattleHook
    def pbDisplayMessage(msg, *args, &block)
      ReadAloud.say(msg)
      super
    end

    def pbDisplay(msg, *args, &block)
      ReadAloud.say(msg)
      super
    end

    def pbDisplayPausedMessage(msg, *args, &block)
      ReadAloud.say(msg)
      super
    end

    def pbShowCommands(msg, *args, &block)
      ReadAloud.say(msg)
      super
    end
  end

  def self.install
    Object.prepend(MessageHook) if Object.private_method_defined?(:pbMessageDisplay) || Object.method_defined?(:pbMessageDisplay)
    Battle::Scene.prepend(BattleHook) if defined?(Battle::Scene)
  rescue StandardError
    nil
  end
end
