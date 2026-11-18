# "What to do" panel: works out the player's main quest, side quests and a few helpful reminders
# from their game, and sends them to the page every couple of seconds (only when something changed).
#
# QUESTS are in story order. Each quest has steps; a step's `done` is true once the player has done
# it. The panel shows the first main quest that isn't finished, at its first unfinished step.
# A quest with `built: false` isn't in the game yet: when the player reaches it, the panel says
# they've reached the end of the story so far. Turn it on (built: true) once it's made.
# Side quests show only once `appears` is true, until they're finished.
# Text can use {rival} and {player}. Keep it short: 12 words or fewer, 6th-grade reading level.
module RTJGuide
  def self.visited?(map_id)
    v = $PokemonGlobal.visitedMaps
    !!(v && v[map_id])
  end

  def self.self_switch?(map_id, event_id, letter = "A")
    $game_self_switches[[map_id, event_id, letter]] ? true : false
  end

  CHORAZIN = 48
  CAPERNAUM = 42
  CANA = 86
  ARBEL_FOREST = 84
  EZER = 9 # Arbel Forest event that battles Ezer and Tova; self switch A is on after

  QUESTS = [
    # ---- Main quests: intro through Cana ----
    { title: "A Visit from the Scribe", type: :main, built: true, steps: [
      { text: "Talk to Mom downstairs in your house.", done: -> { $game_switches[61] } },
      { text: "Meet Ezra upstairs in the Chorazin synagogue.", done: -> { pbGet(7).to_i != 0 } },
    ] },
    { title: "The Old Scribe's Parcel", type: :main, built: true, steps: [
      { text: "Go down Route 1 to Capernaum.", done: -> { visited?(CAPERNAUM) } },
      { text: "Find the man in Capernaum who has Ezra's parcel.", done: -> { $bag.has?(:PARCEL) } },
      { text: "Bring the parcel to Ezra in the Chorazin synagogue.", done: -> { $player.has_pokedex } },
    ] },
    { title: "A Map from Next Door", type: :main, built: true, steps: [
      { text: "Visit {rival}'s mom at her house in Chorazin.", done: -> { $bag.has?(:TOWNMAP) } },
    ] },
    { title: "The Road to Cana", type: :main, built: true, steps: [
      { text: "Take Route 2 from Capernaum toward Cana.", done: -> { visited?(ARBEL_FOREST) } },
      { text: "Get past the Zealots at Arbel Forest's west gate.", done: -> { self_switch?(ARBEL_FOREST, EZER) } },
      { text: "Go west into Cana.", done: -> { visited?(CANA) } },
    ] },
    { title: "The Wedding at Cana", type: :main, built: true, steps: [
      { text: "Find the wine room at the wedding in Cana.", done: -> { pbGet(28).to_i >= 1 } },
      { text: "Fill the empty jug with water at a well in Cana.", done: -> { pbGet(28).to_i >= 2 } },
      { text: "Pour the water into the stone jars in the wine room.", done: -> { pbGet(28).to_i >= 4 } },
      { text: "Take the cup to the Master of the Feast.", done: -> { pbGet(28).to_i >= 5 } },
    ] },
    # ---- Main quests: not built yet ----
    { title: "The Cana Seal", type: :main, built: true, steps: [
      { text: "Earn the Cana Seal from Master Hannah at the Seal House.", done: -> { $player.badges[0] } },
    ] },
    { title: "South to Nazareth", type: :main, built: false, steps: [
      { text: "Take Route 3 south through the cave to Nazareth.", done: -> { false } },
      { text: "Earn the Nazareth Seal from Master Jotham at the Seal House.", done: -> { $player.badges[1] } },
    ] },
    { title: "The Quiet Town", type: :main, built: false, steps: [
      { text: "Take Route 4 east to Nain.", done: -> { false } },
      { text: "Walk through Nain and see what is happening.", done: -> { false } },
    ] },
    { title: "Back to Capernaum", type: :main, built: false, steps: [
      { text: "Take the Tabor road north, back to Capernaum.", done: -> { false } },
      { text: "Try the Seal House in Capernaum. You have two seals now.", done: -> { false } },
      { text: "Earn the Capernaum Seal from Master Nahum.", done: -> { $player.badges[2] } },
    ] },
    { title: "Onto the Water", type: :main, built: false, steps: [
      { text: "Show your Capernaum Seal to the Roman guards on Route 5.", done: -> { false } },
      { text: "Use Surf to go out on the Sea of Galilee.", done: -> { false } },
    ] },
    # ---- Side quests (none built yet) ----
    { title: "A Letter from Father", type: :side, built: false,
      appears: -> { false }, # first time on Route 2
      steps: [
        { text: "Visit the old courier's house on Route 2.", done: -> { false } },
      ] },
    # Ezra's scroll milestones. Switch on (built: true) when Ezra has something to give at each one.
    { title: "Write It All Down", type: :side, built: false,
      appears: -> { $player.has_pokedex },
      steps: [
        { text: "Find 10 kinds of Pokémon for Ezra's scroll.", done: -> { $player.pokedex.seen_count(DEX) >= 10 } },
        { text: "Find 25 kinds of Pokémon for Ezra's scroll.", done: -> { $player.pokedex.seen_count(DEX) >= 25 } },
        { text: "Find 50 kinds of Pokémon for Ezra's scroll.", done: -> { $player.pokedex.seen_count(DEX) >= 50 } },
      ] },
  ].freeze

  END_TEXT = "You reached the end of the story so far! Catch Pokémon while more is made."

  # Index of the first unfinished step (steps.size when finished). A later step being done
  # counts the earlier ones as done too, so out-of-order play still shows the right step.
  def self.step_index(quest)
    last = quest[:steps].rindex do |st|
      begin
        st[:done].call ? true : false
      rescue StandardError
        false
      end
    end
    last ? last + 1 : 0
  end

  def self.quest_info(quest)
    i = step_index(quest)
    return nil if i >= quest[:steps].size
    { "title" => quest[:title], "text" => fill(quest[:steps][i][:text]),
      "step" => i + 1, "of" => quest[:steps].size }
  end

  # The main quest to show: the first unfinished one. nil means the end of what's built.
  def self.main_quest
    QUESTS.each do |q|
      next unless q[:type] == :main
      info = quest_info(q)
      next unless info
      return q[:built] ? info : nil
    end
    nil
  end

  def self.side_quests
    QUESTS.select { |q| q[:type] == :side && q[:built] }.filter_map do |q|
      shown = begin
        q[:appears].call
      rescue StandardError
        false
      end
      shown ? quest_info(q) : nil
    end
  end

  DEX = 0 # the Judea Pokédex (first regional dex)
  @last = nil
  @tick = 0

  def self.fill(text)
    rival = (pbGet(12).to_s rescue "")
    rival = "your friend" if rival.empty? || rival == "0"
    text.gsub("{rival}", rival).gsub("{player}", $player.name.to_s)
  end

  def self.goal
    q = main_quest
    q ? q["text"] : END_TEXT
  end

  def self.balls
    @balls ||= GameData::Item.keys.select { |k| GameData::Item.get(k).is_poke_ball? }
  end

  def self.reminders
    list = []
    party = $player.party
    hurt = party.count { |p| !p.egg? && (p.fainted? || p.hp < p.totalhp / 2) }
    if hurt > 0
      list << (hurt == 1 ? "1 of your Pokémon is hurt." : "#{hurt} of your Pokémon are hurt.") +
              " Rest at a synagogue to heal."
    end
    list << "Your team is full. New Pokémon you catch go to the cabinet in a synagogue." if $player.party_full?
    if $player.party.length > 0 && balls.none? { |b| $bag.has?(b) }
      list << "You have no Poké Balls. Buy more at a market."
    end
    if defined?(RTJAutoSave) && RTJAutoSave.player_off?
      last = RTJAutoSave.instance_variable_get(:@last_time)
      mins = last ? ((Time.now.to_f - last) / 60).floor : 0
      list << "You haven't saved in #{mins} minutes. Save from the menu." if mins >= 15
    end
    if defined?(RTJTrade)
      RTJTrade.trades.each do |t|
        list << "#{t['name']} is waiting for a friend. Code: #{t['code']}"
      end
    end
    list
  end

  # Map name, without behind-the-scenes maps like INTRO
  def self.place
    name = pbGetMapNameFromId($game_map.map_id).to_s
    name =~ /\A(intro|debug)/i ? "" : name.sub(/\s*\((up|down)\)\z/i, "")
  rescue StandardError
    ""
  end

  def self.info
    return {} unless $player && $game_map && $bag && $game_switches && $player.respond_to?(:party)
    @dex_total ||= (pbAllRegionalSpecies(DEX).length rescue 0)
    dex_total = @dex_total
    {
      "goal" => goal.to_s,
      "quest" => main_quest,
      "sides" => side_quests,
      "reminders" => reminders,
      "badges" => $player.badge_count,
      "seen" => ($player.pokedex.seen_count(DEX) rescue 0),
      "caught" => ($player.pokedex.owned_count(DEX) rescue 0),
      "total" => dex_total,
      "hasDex" => $player.has_pokedex ? true : false,
      "place" => place,
    }
  end

  # Called twice a second from Graphics.update; works every 2 seconds
  def self.tick
    @tick += 1
    return unless @tick % 4 == 0
    data = RTJTrade::JSON_LITE.dump(info)
    return if data == @last
    @last = data
    RGSSRuntime.call(:guide, data)
  rescue StandardError => e
    puts "[guide] #{e.class}: #{e.message}" if $__debug
    nil
  end
end
