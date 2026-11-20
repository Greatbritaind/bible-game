# Class sessions (multiplayer). Classmates who joined the same class code see each other walk around.
# They are only pictures: they walk through everything and never start events, battles or cutscenes.
# The page (mp.ts) talks to the server; this file:
#  - sends where the player is, and draws the classmates on the same map (with name tags and emotes);
#  - reads the "class inbox": teacher events (gifts, bonus time, rare swarms, Bible questions),
#    the player's own emotes, and the steps of trades;
#  - runs fair trades: walk up to a classmate and press the action button.
module RTJMP
  NAME_W = 112
  EMOTE_FRAMES = 120
  EMOTE_FILES = { 1 => "emote_exclaim", 2 => "emote_question", 3 => "emote_heart", 4 => "emote_wave", 5 => "emote_happy" }.freeze

  # A classmate on this map: a character that walks toward wherever the classmate is now.
  # Built after the game's scripts load (it needs Game_Character).
  def self.define_ghost
    return if const_defined?(:Ghost, false)
    const_set(:Ghost, Class.new(Game_Character) do
      attr_accessor :target, :tdir, :label, :uid, :emote_seq
      def initialize(map)
        super(map)
        @through = true
        @walk_anime = true
        @step_anime = false
        @move_speed = 4
        @target = nil
        @tdir = 2
        @emote_seq = nil
      end

      def graphic=(name)
        @character_name = name
      end

      def name = "classmate"
      def can_move_in_direction?(*) = true
      def passable?(*) = true
      def check_event_trigger_touch(*) = false
      def increase_steps; end
      def pbCheckEventTriggerAfterTurning; end

      def update
        super
        return if moving? || !@target
        tx, ty = @target
        dx = tx - @x
        dy = ty - @y
        if dx.abs + dy.abs > 5
          moveto(tx, ty)
          @direction = @tdir
        elsif dx != 0 || dy != 0
          @move_speed = (dx.abs + dy.abs > 2) ? 5 : 4
          if dx.abs >= dy.abs then (dx > 0 ? move_right : move_left)
          else (dy > 0 ? move_down : move_up)
          end
        elsif @direction != @tdir
          @direction = @tdir
        end
      end
    end)
  end

  @ghosts = {}       # uid => Ghost
  @sprites = {}      # uid => [Sprite_Character, name sprite]
  @emotes = {}       # :me or uid => [sprite, frames left]
  @last = nil
  @map_id = nil
  @frame = 0
  @active = false
  @busy = false
  @inbox_last = 0
  @queue = []        # things to show when it's safe: gifts, questions, trade requests
  @trade_msgs = []   # trade steps waiting to be read by a trade in progress
  @swarm = nil
  @bonus_until = nil
  @checked_pending = false

  class << self
    attr_reader :ghosts, :ready
  end

  def self.on_map?
    defined?(Scene_Map) && $scene.is_a?(Scene_Map) && $game_map && $game_player && $player && !($game_temp && $game_temp.in_battle)
  end

  def self.now = System.uptime

  # ---------------------------------------------------------------- every frame (from Graphics.update)
  def self.update
    @frame += 1
    install_late unless @late_done
    @active = RGSSRuntime.call(:mp_active).to_i == 1 if @frame % 30 == 1
    poll_inbox if @frame % 10 == 0
    unless @active
      clear unless @ghosts.empty?
      @last = nil
    end
    return unless on_map?
    if @active
      clear if @map_id != $game_map.map_id
      @map_id = $game_map.map_id
      s = state
      if s != @last
        @last = s
        RGSSRuntime.call(:mp_send, s)
      end
      receive if @frame % 3 == 0
      @ghosts.each_value(&:update)
      update_sprites
    end
    update_emotes
    return if @busy
    if !@checked_pending && pending && safe?
      @checked_pending = true
      check_pending
    end
    run_queue if !@queue.empty? && safe?
    talk_to_classmate if @active && safe? && Input.trigger?(Input::USE)
  rescue StandardError => e
    puts "[mp] #{e.class}: #{e.message} #{e.backtrace&.first}" if $__debug
  end

  def self.safe?
    return false if @busy
    return false unless defined?(RTJAutoSave) && RTJAutoSave.safe?
    return false if $game_player.moving?
    true
  end

  # The player's map, tile, facing and look, sent whenever one of them changes
  def self.state
    name = $player.name.to_s.gsub(/[|\n]/, " ")[0, 16]
    place = ($game_map.name rescue "").to_s.gsub(/[|\n]/, " ")[0, 32]
    [$game_map.map_id, $game_player.x, $game_player.y, $game_player.direction,
     $game_player.character_name.to_s.gsub(/[|\n]/, ""), name, place].join("|")
  end

  # One line per classmate on this map: uid|name|x|y|direction|emoteSeq|emote|character graphic
  def self.receive
    text = RGSSRuntime.call(:mp_read).to_s
    return if text == "~"
    seen = {}
    text.each_line do |line|
      uid, name, x, y, d, es, e, gfx = line.chomp.split("|", 8)
      next if uid.nil? || uid.empty? || gfx.nil?
      seen[uid] = true
      g = @ghosts[uid]
      unless g
        g = Ghost.new($game_map)
        g.moveto(x.to_i, y.to_i)
        g.uid = uid
        g.emote_seq = es.to_i # don't replay an old emote
        @ghosts[uid] = g
      end
      g.graphic = gfx unless gfx.empty?
      g.target = [x.to_i, y.to_i]
      g.tdir = [2, 4, 6, 8].include?(d.to_i) ? d.to_i : 2
      g.label = name
      if es.to_i != g.emote_seq
        g.emote_seq = es.to_i
        show_emote(uid, e.to_i)
      end
    end
    (@ghosts.keys - seen.keys).each { |uid| remove(uid) }
  end

  def self.update_sprites
    vp = Spriteset_Map.viewport
    @ghosts.each do |uid, g|
      sp, tag = @sprites[uid]
      if sp.nil? || sp.disposed?
        sp = Sprite_Character.new(vp, g)
        tag = Sprite.new(vp)
        tag.bitmap = Bitmap.new(NAME_W, 20)
        tag.instance_variable_set(:@label, nil)
        @sprites[uid] = [sp, tag]
      end
      sp.update
      if tag.instance_variable_get(:@label) != g.label
        tag.instance_variable_set(:@label, g.label)
        b = tag.bitmap
        b.clear
        b.font.size = 16
        b.font.bold = true
        b.font.color = Color.new(40, 40, 48)
        [[-1, 0], [1, 0], [0, -1], [0, 1]].each { |ox, oy| b.draw_text(ox, 2 + oy, NAME_W, 16, g.label.to_s, 1) }
        b.font.color = Color.new(255, 255, 255)
        b.draw_text(0, 2, NAME_W, 16, g.label.to_s, 1)
      end
      tag.x = g.screen_x - NAME_W / 2
      tag.y = g.screen_y - 70
      tag.z = 3500
      tag.visible = sp.visible
    end
  end

  def self.remove(uid)
    @ghosts.delete(uid)
    sp, tag = @sprites.delete(uid)
    sp&.dispose
    if tag
      tag.bitmap&.dispose
      tag.dispose
    end
    hide_emote(uid)
  end

  def self.clear
    @ghosts.keys.each { |uid| remove(uid) }
  end

  # ---------------------------------------------------------------- emotes
  def self.show_emote(who, e)
    file = EMOTE_FILES[e]
    return unless file
    hide_emote(who)
    sp = Sprite.new(Spriteset_Map.viewport)
    sp.bitmap = RPG::Cache.load_bitmap("Graphics/Pictures/Emotes/", file) rescue nil
    sp.z = 3600
    @emotes[who] = [sp, EMOTE_FRAMES]
  end

  def self.hide_emote(who)
    sp, = @emotes.delete(who)
    sp&.dispose
  end

  def self.update_emotes
    @emotes.keys.each do |who|
      sp, left = @emotes[who]
      ch = who == :me ? $game_player : @ghosts[who]
      if ch.nil? || left <= 0 || sp.disposed?
        hide_emote(who)
        next
      end
      @emotes[who][1] = left - 1
      w = sp.bitmap ? sp.bitmap.width : 32
      sp.x = ch.screen_x - w / 2
      bob = left > EMOTE_FRAMES - 8 ? (EMOTE_FRAMES - left) * 2 - 16 : 0
      sp.y = ch.screen_y - 84 + (who == :me ? 12 : 0) + bob
      sp.opacity = left < 16 ? left * 16 : 255
    end
  end

  # ---------------------------------------------------------------- the class inbox
  def self.poll_inbox
    text = RGSSRuntime.call(:mp_inbox).to_s
    return if text == "~" || text.empty?
    top = @inbox_last
    text.each_line do |line|
      m = RTJTrade::JSON_LITE.parse(line) rescue nil
      next unless m.is_a?(Hash)
      id = m["id"].to_i
      next if id <= @inbox_last
      top = id if id > top
      handle(m)
    end
    if top > @inbox_last
      @inbox_last = top
      RGSSRuntime.call(:mp_cmd, RTJTrade::JSON_LITE.dump({ "k" => "ack", "id" => top }))
    end
  end

  def self.handle(m)
    case m["k"]
    when "emote" then show_emote(:me, m["e"].to_i)
    when "gift", "question" then @queue << m unless done?(m["ev"])
    when "bonus" then @bonus_until = now + m["rem"].to_i / 1000.0
    when "swarm"
      species = (GameData::Species.get(m["species"].to_s.upcase.to_sym).id rescue nil)
      map = m["map"].to_i
      if species && map > 0
        @swarm = { map: map, species: species, level: m["level"].to_i.clamp(2, 60), until: now + m["rem"].to_i / 1000.0, name: m["place"].to_s }
        @queue << { "k" => "swarm_note", "ev" => m["ev"], "species" => species, "place" => m["place"].to_s } unless done?("note-" + m["ev"].to_s)
      end
    when "trade_ask" then @queue << m
    when "trade_started", "trade_state", "trade_error" then @trade_msgs << m
    end
  end

  def self.done_list
    g = $PokemonGlobal
    h = g.instance_variable_get(:@rtj_class_done)
    unless h.is_a?(Hash)
      h = {}
      g.instance_variable_set(:@rtj_class_done, h)
    end
    h
  end

  def self.done?(ev) = !ev.nil? && done_list.key?(ev.to_s)
  def self.mark_done(ev) = done_list[ev.to_s] = Time.now.to_i

  def self.run_queue
    m = @queue.shift
    return unless m
    @busy = true
    case m["k"]
    when "gift" then run_gift(m)
    when "question" then run_question(m)
    when "swarm_note" then run_swarm_note(m)
    when "trade_ask" then answer_trade(m)
    end
  ensure
    @busy = false
  end

  # ---------------------------------------------------------------- teacher events
  def self.run_gift(m)
    return if done?(m["ev"])
    item = (GameData::Item.get(m["item"].to_s.upcase.to_sym) rescue nil)
    qty = m["qty"].to_i.clamp(1, 99)
    mark_done(m["ev"])
    return unless item
    $bag.add(item.id, qty)
    RTJTrade.save_game
    pbMessage(_INTL("\\me[Item get]Your teacher sent everyone a gift!\\wtnp[30]"))
    name = qty > 1 ? item.name_plural : item.name
    pbMessage(_INTL("You got {1} {2}!", qty, name))
  end

  def self.run_question(m)
    return if done?(m["ev"])
    if m["rem"].to_i > 0 && @question_end.nil?
      # (timing is checked by the page; a question shows once)
    end
    mark_done(m["ev"])
    choices = Array(m["choices"]).map(&:to_s).reject(&:empty?)[0, 4]
    return if choices.length < 2
    pbMessage(_INTL("\\se[GUI sel decision]A question from your teacher!"))
    pick = pbMessage(m["q"].to_s, choices, -1)
    right = pick == m["answer"].to_i
    RGSSRuntime.call(:mp_cmd, RTJTrade::JSON_LITE.dump({ "k" => "answer", "ev" => m["ev"].to_s, "ok" => right, "n" => $player.name.to_s }))
    if right
      item = (GameData::Item.get(m["reward"].to_s.upcase.to_sym) rescue nil)
      if item
        $bag.add(item.id, 1)
        pbMessage(_INTL("\\me[Item get]That's right! You got {1}!\\wtnp[30]", item.name))
      else
        pbMessage(_INTL("That's right! Well done!"))
      end
    else
      pbMessage(_INTL("Not quite. The answer was: {1}", choices[m["answer"].to_i].to_s))
    end
    RTJTrade.save_game
  end

  def self.run_swarm_note(m)
    mark_done("note-" + m["ev"].to_s)
    sp = (GameData::Species.get(m["species"]).name rescue m["species"].to_s)
    place = m["place"].to_s
    pbMessage(_INTL("Your teacher says a rare {1} was seen in {2}! Hurry!", sp, place.empty? ? _INTL("the wild") : place))
  end

  def self.swarm_species(encounter)
    s = @swarm
    return unless s && encounter && now < s[:until] && $game_map && $game_map.map_id == s[:map]
    return unless rand(100) < 40
    encounter[0] = s[:species]
    encounter[1] = s[:level]
  end

  def self.bonus? = !@bonus_until.nil? && now < @bonus_until

  # ---------------------------------------------------------------- fair trades
  # The player who walks up (A) picks what to offer and asks. The other player (B) sees it, picks
  # what to give, and their Pokémon goes into the trade. A sees B's offer and agrees, and A's goes
  # in. Only then can either game read the other's Pokémon (the server enforces this). A Pokémon
  # put into a trade leaves the party and the game is saved right away, so reloading can't copy it;
  # if the trade is called off, it comes back.
  def self.pending
    $PokemonGlobal&.instance_variable_get(:@rtj_pending_trade)
  end

  def self.set_pending(v)
    $PokemonGlobal.instance_variable_set(:@rtj_pending_trade, v)
  end

  def self.talk_to_classmate
    dx = { 4 => -1, 6 => 1 }[$game_player.direction] || 0
    dy = { 8 => -1, 2 => 1 }[$game_player.direction] || 0
    fx = $game_player.x + dx
    fy = $game_player.y + dy
    return if $game_map.events.values.any? { |e| e.x == fx && e.y == fy && !e.instance_variable_get(:@erased) && !e.character_name.to_s.empty? }
    g = @ghosts.values.find { |gh| gh.x == fx && gh.y == fy && !gh.moving? }
    return unless g
    @busy = true
    ask_trade(g)
  ensure
    @busy = false
  end

  def self.summary(pkmn)
    { "name" => pkmn.name.to_s, "species" => pkmn.species.to_s, "level" => pkmn.level }
  end

  def self.describe(offer)
    return _INTL("a Pokémon") unless offer.is_a?(Hash)
    sp = (GameData::Species.get(offer["species"].to_s.to_sym).name rescue offer["species"].to_s)
    nm = offer["name"].to_s
    base = nm.empty? || nm == sp ? sp : "#{nm} (#{sp})"
    _INTL("{1}, level {2}", base, offer["level"].to_i)
  end

  def self.can_trade?
    if pending
      pbMessage(_INTL("You're still finishing a trade. Wait a moment."))
      return false
    end
    able = $player.party.count { |p| !p.egg? && !p.fainted? }
    if $player.party.length < 2 || able < 2
      pbMessage(_INTL("You need at least two healthy Pokémon to trade."))
      return false
    end
    true
  end

  # Returns the party index of the Pokémon to trade, or nil
  def self.choose_pokemon(text)
    pbMessage(text)
    chosen = -1
    pbFadeOutIn do
      scene = PokemonParty_Scene.new
      screen = PokemonPartyScreen.new(scene, $player.party)
      chosen = screen.pbChooseTradablePokemon(proc { |p| !p.egg? && !(p.respond_to?(:shadowPokemon?) && p.shadowPokemon?) })
    end
    return nil if chosen.nil? || chosen < 0
    others = $player.party.each_with_index.count { |p, i| i != chosen && !p.egg? && !p.fainted? }
    if others < 1
      pbMessage(_INTL("You can't trade away your last healthy Pokémon."))
      return nil
    end
    chosen
  end

  def self.send_cmd(h) = RGSSRuntime.call(:mp_cmd, RTJTrade::JSON_LITE.dump(h))

  # Waits for a trade step. Returns the message, or nil if the player gave up (only when allowed).
  def self.wait_trade(text, tid: nil, ref: nil, can_cancel: true, timeout: 180)
    win = pbCreateMessageWindow
    pbMessageDisplay(win, text + (can_cancel ? "\n" + _INTL("Press Back to stop.") : "") + "\\wtnp[0]")
    start = now
    loop do
      Graphics.update
      Input.update
      win.update
      poll_inbox
      i = @trade_msgs.index { |m| (tid && m["tid"].to_s == tid) || (ref && m["ref"].to_s == ref) }
      if i
        m = @trade_msgs.delete_at(i)
        next if m["k"] == "trade_state" && %w[ask].include?(m["st"].to_s)
        return m
      end
      return nil if can_cancel && Input.trigger?(Input::BACK)
      return { "k" => "trade_timeout" } if now - start > timeout
    end
  ensure
    pbDisposeMessageWindow(win) if win
  end

  # Puts the Pokémon into the trade: off the party, remembered in the save, saved
  def self.escrow(idx, tid, role, partner)
    pkmn = $player.party[idx]
    packed = RTJTrade.pack(pkmn)
    $player.party.delete_at(idx)
    set_pending({ "tid" => tid, "role" => role, "mine" => packed, "name" => pkmn.name.to_s, "partner" => partner.to_s })
    RTJTrade.save_game
    RTJTrade.refresh_follower
    packed
  end

  def self.give_back(message = nil)
    p = pending
    return unless p
    pkmn = RTJTrade.unpack(p["mine"])
    puts "[mp] trade called off: #{pkmn&.name} back" if $__debug
    set_pending(nil)
    if pkmn
      RTJTrade.store(pkmn)
      pbMessage(message || _INTL("{1} came back to you.", pkmn.name))
    end
    RTJTrade.save_game
    RTJTrade.refresh_follower
  end

  def self.finish_trade(packed)
    p = pending
    pkmn = RTJTrade.unpack(packed)
    unless pkmn
      give_back(_INTL("Something went wrong with the trade, so {1} came back to you.", p ? p["name"] : "your Pokémon"))
      return
    end
    pkmn.obtain_method = 2 rescue nil
    pkmn.calc_stats rescue nil
    mine = (RTJTrade.unpack(p["mine"]) rescue nil)
    RTJTrade.store(pkmn)
    set_pending(nil)
    RTJTrade.save_game
    puts "[mp] traded: gave #{mine&.name} got #{pkmn.name} party=#{$player.party.map(&:name).join(',')}" if $__debug
    send_cmd({ "k" => "trade_done", "tid" => p["tid"].to_s, "role" => p["role"].to_s })
    RTJTrade.refresh_follower
    RTJTrade.animation(mine, true) if mine
    RTJTrade.animation(pkmn, false)
    pbMessage(_INTL("You got {1}!\\me[Pkmn get]\\wtnp[60]", pkmn.name))
    pbMessage(_INTL("Take good care of {1}.", pkmn.name))
    RTJTrade.trade_evolution(pkmn)
  end

  # After escrow: wait until the trade finishes or is called off
  def self.wait_result(partner)
    loop do
      m = wait_trade(_INTL("Trading with {1}...", partner), tid: pending["tid"].to_s, can_cancel: false, timeout: 120)
      st = m["st"].to_s
      if m["k"] == "trade_state" && st == "swap"
        finish_trade(m["pkmn"].to_s)
        return
      elsif m["k"] == "trade_state" && %w[cancel decline gone].include?(st)
        give_back(_INTL("{1} stopped the trade. Your Pokémon came back to you.", partner))
        return
      elsif m["k"] == "trade_timeout"
        if pbConfirmMessage(_INTL("{1} is taking a long time. Stop the trade?", partner))
          send_cmd({ "k" => "trade_cancel", "tid" => pending["tid"].to_s })
        end
      elsif m["k"] == "trade_error"
        pbMessage(_INTL("The connection had a problem. Trying again..."))
        send_cmd({ "k" => "trade_check", "tid" => pending["tid"].to_s, "role" => pending["role"].to_s })
      end
    end
  end

  # A: walk up and ask
  def self.ask_trade(g)
    partner = g.label.to_s
    return unless pbConfirmMessage(_INTL("Trade with {1}?", partner))
    return unless can_trade?
    idx = choose_pokemon(_INTL("Choose a Pokémon to offer {1}.", partner))
    return unless idx
    mine = $player.party[idx]
    ref = "r#{rand(1_000_000)}"
    send_cmd({ "k" => "trade_ask", "ref" => ref, "to" => g.uid, "toName" => partner, "me" => $player.name.to_s, "offer" => summary(mine) })
    m = wait_trade(_INTL("Asking {1}...", partner), ref: ref, can_cancel: false, timeout: 30)
    unless m && m["k"] == "trade_started"
      pbMessage(_INTL("Couldn't reach {1}. Try again.", partner))
      return
    end
    tid = m["tid"].to_s
    m = wait_trade(_INTL("Waiting for {1}...", partner), tid: tid)
    if m.nil? || m["k"] == "trade_timeout"
      send_cmd({ "k" => "trade_cancel", "tid" => tid })
      pbMessage(_INTL("You stopped the trade."))
      return
    end
    st = m["st"].to_s
    if st == "decline"
      pbMessage(_INTL("{1} said no thanks.", partner))
      return
    elsif st != "offered"
      pbMessage(_INTL("The trade was stopped."))
      return
    end
    # B's Pokémon is in the trade now. Check A's choice is still in the party (same slot).
    unless $player.party[idx].equal?(mine)
      send_cmd({ "k" => "trade_cancel", "tid" => tid })
      pbMessage(_INTL("Your team changed, so the trade was stopped."))
      return
    end
    unless pbConfirmMessage(_INTL("{1} offers {2}.\nTrade your {3} for it?", partner, describe(m["offer"]), mine.name))
      send_cmd({ "k" => "trade_cancel", "tid" => tid })
      pbMessage(_INTL("You said no thanks. {1} gets their Pokémon back.", partner))
      return
    end
    packed = escrow(idx, tid, "a", partner)
    send_cmd({ "k" => "trade_confirm", "tid" => tid, "pkmn" => packed })
    wait_result(partner)
  end

  # B: someone asked
  def self.answer_trade(m)
    tid = m["tid"].to_s
    partner = m["from"].to_s
    if !@active
      send_cmd({ "k" => "trade_decline", "tid" => tid })
      return
    end
    choice = pbMessage(_INTL("{1} wants to trade! They offer {2}.", partner, describe(m["offer"])),
                       [_INTL("Trade"), _INTL("No thanks")], 2)
    unless choice == 0 && can_trade?
      send_cmd({ "k" => "trade_decline", "tid" => tid })
      return
    end
    idx = choose_pokemon(_INTL("Choose a Pokémon to give {1}.", partner))
    unless idx
      send_cmd({ "k" => "trade_decline", "tid" => tid })
      return
    end
    pk = $player.party[idx]
    unless pbConfirmMessage(_INTL("Offer your {1} for {2}?", pk.name, describe(m["offer"])))
      send_cmd({ "k" => "trade_decline", "tid" => tid })
      return
    end
    packed = escrow(idx, tid, "b", partner)
    send_cmd({ "k" => "trade_offer", "tid" => tid, "pkmn" => packed, "offer" => summary(pk) })
    wait_result(partner)
  end

  # After a reload or a lost connection: finish or undo a trade that was in progress
  def self.check_pending
    p = pending
    return unless p
    @busy = true
    send_cmd({ "k" => "trade_check", "tid" => p["tid"].to_s, "role" => p["role"].to_s })
    m = wait_trade(_INTL("Finishing your trade with {1}...", p["partner"]), tid: p["tid"].to_s, can_cancel: false, timeout: 20)
    st = m && m["st"].to_s
    if m && m["k"] == "trade_state" && st == "swap"
      finish_trade(m["pkmn"].to_s)
    elsif m && m["k"] == "trade_state" && %w[cancel decline gone].include?(st)
      give_back
    elsif m && m["k"] == "trade_state"
      # still waiting on the other player: call it off and take the Pokémon back
      send_cmd({ "k" => "trade_cancel", "tid" => p["tid"].to_s })
      m2 = wait_trade(_INTL("Stopping the trade..."), tid: p["tid"].to_s, can_cancel: false, timeout: 20)
      if m2 && m2["st"].to_s == "swap" then finish_trade(m2["pkmn"].to_s)
      else give_back
      end
    else
      @checked_pending = false # couldn't reach the server: try again later
    end
  ensure
    @busy = false
  end

  # ---------------------------------------------------------------- setup
  def self.install
    return unless defined?(Scene_Map) && defined?(Game_Character)
    define_ghost
    if defined?(EventHandlers)
      EventHandlers.add(:on_wild_species_chosen, :rtj_class_swarm, proc { |encounter| RTJMP.swarm_species(encounter) })
    end
    @ready = true
  rescue StandardError => e
    puts "[mp] install: #{e.message}" if $__debug
  end

  # Bonus time: double prize money (Happy Hour) and more EXP (like the Exp. Charm). Hooked on the
  # first frame, after the game's plugins have loaded, with aliases (like the plugins do).
  def self.install_late
    @late_done = true
    if defined?(Battle) && Battle.method_defined?(:pbGainMoney) && !Battle.method_defined?(:__rtj_pbGainMoney)
      Battle.class_eval do
        alias_method :__rtj_pbGainMoney, :pbGainMoney
        def pbGainMoney
          (@field.effects[PBEffects::HappyHour] = true) if RTJMP.bonus? rescue nil
          __rtj_pbGainMoney
        end
      end
    end
    if defined?(PokemonBag) && PokemonBag.method_defined?(:has?) && !PokemonBag.method_defined?(:__rtj_has?)
      PokemonBag.class_eval do
        alias_method :__rtj_has?, :has?
        def has?(item, qty = 1)
          return true if item == :EXPCHARM && qty <= 1 && RTJMP.bonus?
          __rtj_has?(item, qty)
        end
      end
    end
  rescue StandardError => e
    puts "[mp] install_late: #{e.message}" if $__debug
  end
end
