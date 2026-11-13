# Trading between players: a Pokémon is put in an online mailbox and the sender gets a short code
# (like LAMB-FIG-4). Whoever types the code at a Trader gets the Pokémon. Each code works once.
#
# In RPG Maker, make an event with the script command:   pbTradeCenter
module RTJTrade
  CLAIM_DAYS = 7
  # Only these kinds of objects may come out of a received Pokémon (protects against broken or fake data)
  SAFE_CLASSES = %w[
    Pokemon Pokemon::Owner Pokemon::Move Mail
    String Symbol Integer Float Array Hash NilClass TrueClass FalseClass Time Rational
  ].freeze

  def self.request(action, data)
    text = RGSSRuntime.call(:trade, action.to_s, JSON_LITE.dump(data)).to_s
    return { "ok" => false, "message" => "Could not reach the trading post. Check the internet and try again." } if text.empty?
    JSON_LITE.parse(text)
  rescue StandardError
    { "ok" => false, "message" => "Something went wrong with the trade. Try again." }
  end

  def self.pack(pkmn)
    [Zlib::Deflate.deflate(Marshal.dump(pkmn))].pack("m0")
  end

  def self.unpack(text)
    raw = Zlib::Inflate.inflate(text.to_s.unpack1("m0"))
    allowed = SAFE_CLASSES.map { |n| Object.const_get(n) rescue nil }.compact
    pkmn = Marshal.load(raw, proc do |obj|
      unless obj.is_a?(Module) || allowed.any? { |c| obj.instance_of?(c) }
        raise TypeError, "not allowed: #{obj.class}"
      end
      obj
    end)
    pkmn.is_a?(Pokemon) ? pkmn : nil
  rescue StandardError, TypeError, ArgumentError
    nil
  end

  def self.online?
    RGSSRuntime.call(:trade_available).to_i == 1
  rescue StandardError
    false
  end

  def self.trades
    g = $PokemonGlobal
    list = g.instance_variable_get(:@rtj_trades)
    unless list.is_a?(Array)
      list = []
      g.instance_variable_set(:@rtj_trades, list)
    end
    list
  end

  def self.save_game
    Game.save
    RGSSRuntime.call(:sync_saves)
  rescue StandardError
    nil
  end

  def self.refresh_follower
    FollowingPkmn.refresh(false) if defined?(FollowingPkmn)
  rescue StandardError
    nil
  end

  # Shows a message while the game waits for the trading post
  def self.while_waiting(text)
    win = pbCreateMessageWindow
    pbMessageDisplay(win, text + "\\wtnp[0]")
    Graphics.update
    yield
  ensure
    pbDisposeMessageWindow(win) if win
  end

  def self.spell(code)
    code.to_s.split("-").join(" - ")
  end

  # Plays the Poké Ball leaving (sending) or arriving (receiving)
  def self.animation(pkmn, sending)
    scene_class = trade_scene_class
    pbFadeOutInWithMusic do
      scene = scene_class.new
      scene.rtj_start(pkmn)
      if sending
        scene.rtj_send
      else
        scene.rtj_receive
      end
      scene.rtj_finish
    end
  rescue StandardError
    nil # the animation is only decoration
  end

  def self.trade_scene_class
    return @scene_class if @scene_class
    @scene_class = Class.new(PokemonTrade_Scene) do
      def rtj_start(pkmn)
        @sprites = {}
        @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @viewport.z = 99999
        @pokemon = pkmn
        @pokemon2 = pkmn
        addBackgroundOrColoredPlane(@sprites, "background", "trade_bg", Color.new(248, 248, 248), @viewport)
        %w[rsprite1 rsprite2].each do |key|
          s = PokemonSprite.new(@viewport)
          s.setPokemonBitmap(pkmn, false)
          s.setOffset(PictureOrigin::BOTTOM)
          s.x = Graphics.width / 2
          s.y = 264
          s.z = 10
          pkmn.species_data.apply_metrics_to_sprite(s, 1)
          @sprites[key] = s
        end
        @sprites["msgwindow"] = pbCreateMessageWindow(@viewport)
        @sprites["msgwindow"].visible = false
      end

      def rtj_send
        @sprites["rsprite2"].visible = false
        pbFadeInAndShow(@sprites) { pbUpdate }
        pbBGMPlay("Evolution")
        pbScene1
        pbBGMStop
      end

      def rtj_receive
        @sprites["rsprite1"].visible = false
        @sprites["rsprite2"].visible = false
        pbFadeInAndShow(@sprites) { pbUpdate }
        @sprites["rsprite2"].visible = false
        pbBGMPlay("Evolution")
        pbScene2
        pbBGMStop
        pbMEPlay("Battle capture success")
      end

      def rtj_finish
        pbDisposeMessageWindow(@sprites["msgwindow"]) if @sprites["msgwindow"]
        @sprites.delete("msgwindow")
        pbFadeOutAndHide(@sprites)
        pbDisposeSpriteHash(@sprites)
        @viewport.dispose
      end
    end
  end

  # ---------------------------------------------------------------------------------------------

  def self.main
    unless online?
      pbMessage(_INTL("Trading only works in the online game."))
      return
    end
    check_my_trades
    loop do
      cmd = pbMessage(_INTL("Welcome to the trading post! What would you like to do?"),
                      [_INTL("Send a Pokémon"), _INTL("Get a Pokémon"), _INTL("My trade codes"), _INTL("Leave")], 4)
      case cmd
      when 0 then send_pokemon
      when 1 then receive_pokemon
      when 2 then my_trades
      else break
      end
    end
    pbMessage(_INTL("Come back any time!"))
  end

  def self.send_pokemon
    able = $player.party.count { |p| !p.egg? && !p.fainted? }
    if $player.party.length < 2 || able < 2
      pbMessage(_INTL("You need at least two healthy Pokémon to send one away."))
      return
    end
    chosen = -1
    pbFadeOutIn do
      scene = PokemonParty_Scene.new
      screen = PokemonPartyScreen.new(scene, $player.party)
      chosen = screen.pbChooseTradablePokemon(proc { |p| !p.egg? && !(p.respond_to?(:shadowPokemon?) && p.shadowPokemon?) })
    end
    return if chosen.nil? || chosen < 0
    pkmn = $player.party[chosen]
    others = $player.party.each_with_index.count { |p, i| i != chosen && !p.egg? && !p.fainted? }
    if others < 1
      pbMessage(_INTL("You can't send away your last healthy Pokémon."))
      return
    end
    return unless pbConfirmMessage(_INTL("Send {1} to a friend?", pkmn.name))
    gift = pkmn.clone
    gift.owner = Pokemon::Owner.new_foreign(_INTL("Friend"), 0) # the player's name never leaves the computer
    res = while_waiting(_INTL("Sending...")) { request(:send, { "pokemon" => pack(gift) }) }
    unless res["ok"]
      pbMessage(res["message"].to_s)
      return
    end
    code = res["code"].to_s
    $player.party.delete_at(chosen)
    trades << { "code" => code, "secret" => res["secret"].to_s, "name" => pkmn.name.to_s, "pokemon" => pack(pkmn), "time" => Time.now.to_i }
    save_game
    refresh_follower
    animation(pkmn, true)
    show_code(code, pkmn.name)
  end

  def self.show_code(code, name)
    pbMessage(_INTL("{1} is waiting for your friend.", name))
    loop do
      cmd = pbMessage(_INTL("Your trade code is:\n\\c[1]{1}", spell(code)), [_INTL("Show it again"), _INTL("Done")], 2)
      break if cmd != 0
    end
    pbMessage(_INTL("Tell your friend the code. They type it in at a trading post."))
  end

  def self.receive_pokemon
    if pbBoxesFull?
      pbMessage(_INTL("You have no room for more Pokémon!"))
      return
    end
    text = type_code
    return if text.nil? || text.strip.empty?
    res = while_waiting(_INTL("Checking the code...")) { request(:claim, { "code" => text }) }
    unless res["ok"]
      pbMessage(res["message"].to_s + "\n" + _INTL("Check the code and try again."))
      return
    end
    pkmn = unpack(res["pokemon"])
    unless pkmn
      pbMessage(_INTL("That Pokémon could not be opened. Ask your friend to send it again."))
      return
    end
    pkmn.obtain_method = 2 rescue nil # traded
    pkmn.calc_stats rescue nil
    store(pkmn)
    save_game
    refresh_follower
    animation(pkmn, false)
    pbMessage(_INTL("You got {1}!\\me[Pkmn get]\\wtnp[60]", pkmn.name))
    pbMessage(_INTL("Take good care of {1}.", pkmn.name))
    trade_evolution(pkmn)
  end

  # Code entry always uses the typing screen (not the letter grid), so students can type on the keyboard
  def self.type_code
    old = $PokemonSystem.textinput
    $PokemonSystem.textinput = 1
    pbEnterText(_INTL("Type the trade code"), 1, 16)
  ensure
    $PokemonSystem.textinput = old
  end

  def self.store(pkmn)
    $player.pokedex.register(pkmn)
    $player.pokedex.set_owned(pkmn.species)
    if $player.party_full?
      box = $PokemonStorage.pbStoreCaught(pkmn)
      pbMessage(_INTL("{1} was sent to Box \"{2}\".", pkmn.name, $PokemonStorage[box].name)) rescue nil
    else
      $player.party[$player.party.length] = pkmn
    end
  end

  def self.trade_evolution(pkmn)
    return unless $player.party.include?(pkmn)
    newspecies = pkmn.check_evolution_on_trade(pkmn) rescue nil
    return unless newspecies
    pbFadeOutInWithMusic do
      evo = PokemonEvolutionScene.new
      evo.pbStartScreen(pkmn, newspecies)
      evo.pbEvolution(false)
      evo.pbEndScreen
    end
    save_game
    refresh_follower
  end

  # Finds out which sent Pokémon were picked up, and brings back ones nobody took in time
  def self.check_my_trades
    trades.dup.each do |t|
      res = request(:status, { "code" => t["code"], "secret" => t["secret"] })
      next unless res["ok"]
      case res["status"]
      when "gone"
        trades.delete(t)
        save_game
        pbMessage(_INTL("Good news! A friend picked up your {1}.", t["name"]))
      when "expired"
        take_back(t, _INTL("Nobody picked up {1} in time, so it came back to you.", t["name"]))
      end
    end
  end

  def self.my_trades
    if trades.empty?
      pbMessage(_INTL("You have no Pokémon waiting to be picked up."))
      return
    end
    names = trades.map { |t| "#{t['name']}: #{t['code']}" }
    cmd = pbMessage(_INTL("These Pokémon are waiting for a friend."), names + [_INTL("Back")], names.length + 1)
    return if cmd < 0 || cmd >= trades.length
    t = trades[cmd]
    choice = pbMessage(_INTL("{1}'s code is:\n\\c[1]{2}", t["name"], spell(t["code"])),
                       [_INTL("Keep waiting"), _INTL("Take it back")], 1)
    return unless choice == 1
    return unless pbConfirmMessage(_INTL("Take {1} back? The code will stop working.", t["name"]))
    take_back(t, nil)
  end

  def self.take_back(t, message)
    if pbBoxesFull?
      pbMessage(_INTL("Make room in your boxes to take {1} back.", t["name"]))
      return
    end
    res = request(:cancel, { "code" => t["code"], "secret" => t["secret"] })
    unless res["ok"]
      trades.delete(t)
      save_game
      pbMessage(_INTL("A friend already picked up your {1}!", t["name"]))
      return
    end
    pkmn = unpack(t["pokemon"])
    trades.delete(t)
    if pkmn
      store(pkmn)
      pbMessage(message || _INTL("{1} came back to you!", pkmn.name))
    end
    save_game
    refresh_follower
  end

  # Small JSON reader/writer (the game has no JSON library). Only what the trading post needs.
  module JSON_LITE
    def self.dump(obj)
      case obj
      when Hash then "{" + obj.map { |k, v| dump(k.to_s) + ":" + dump(v) }.join(",") + "}"
      when Array then "[" + obj.map { |v| dump(v) }.join(",") + "]"
      when String
        '"' + obj.gsub(/[\\"\u0000-\u001f]/) { |c| c == "\\" ? "\\\\" : c == '"' ? '\\"' : format("\\u%04x", c.ord) } + '"'
      when Integer, Float then obj.to_s
      when true then "true"
      when false then "false"
      else "null"
      end
    end

    def self.parse(text)
      s = text.strip
      v, i = value(s, 0)
      v
    end

    def self.skip(s, i)
      i += 1 while i < s.length && " \t\r\n".include?(s[i])
      i
    end

    def self.value(s, i)
      i = skip(s, i)
      case s[i]
      when "{"
        h = {}
        i = skip(s, i + 1)
        return [h, i + 1] if s[i] == "}"
        loop do
          k, i = value(s, i)
          i = skip(s, i) + 1 # ':'
          v, i = value(s, i)
          h[k] = v
          i = skip(s, i)
          i += 1
          break if s[i - 1] == "}"
        end
        [h, i]
      when "["
        a = []
        i = skip(s, i + 1)
        return [a, i + 1] if s[i] == "]"
        loop do
          v, i = value(s, i)
          a << v
          i = skip(s, i)
          i += 1
          break if s[i - 1] == "]"
        end
        [a, i]
      when '"'
        out = +""
        i += 1
        while s[i] != '"'
          if s[i] == "\\"
            c = s[i + 1]
            case c
            when "u" then out << s[i + 2, 4].hex.chr(Encoding::UTF_8); i += 6
            when "n" then out << "\n"; i += 2
            when "t" then out << "\t"; i += 2
            when "r" then out << "\r"; i += 2
            when "b" then out << "\b"; i += 2
            when "f" then out << "\f"; i += 2
            else out << c; i += 2
            end
          else
            out << s[i]
            i += 1
          end
        end
        [out, i + 1]
      when "t" then [true, i + 4]
      when "f" then [false, i + 5]
      when "n" then [nil, i + 4]
      else
        m = s[i..].match(/\A-?\d+(\.\d+)?([eE][-+]?\d+)?/)
        [m[1] || m[2] ? m[0].to_f : m[0].to_i, i + m[0].length]
      end
    end
  end
end

def pbTradeCenter
  RTJTrade.main
end
