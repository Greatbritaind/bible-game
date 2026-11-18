# "What to do" panel: works out the player's next story goal and a few helpful reminders from their
# game, and sends them to the page every couple of seconds (only when something changed).
#
# STORY STEPS: in order. The first step whose `todo` is true is the goal shown to the player.
# To add a step, add a line in the right place. Text can use {rival} and {player}.
module RTJGuide
  STEPS = [
    { todo: -> { !$game_switches[61] },
      text: "Talk to Mom downstairs in your house." },
    { todo: -> { pbGet(7).to_i == 0 },
      text: "Go to the synagogue in Chorazin. Ezra the old scribe is waiting for you." },
    { todo: -> { !$player.has_pokedex && !$bag.has?(:PARCEL) },
      text: "Go to Capernaum. Find the Pharisee who has Ezra's parcel." },
    { todo: -> { $bag.has?(:PARCEL) },
      text: "Bring the parcel back to Ezra at the synagogue in Chorazin." },
    { todo: -> { !$bag.has?(:TOWNMAP) },
      text: "Visit {rival}'s mom at their house. She has something for you." },
    { todo: -> { pbGet(28).to_i == 0 },
      text: "Go to Cana. There is a wedding there. Find the wine room and see if they need help." },
    { todo: -> { pbGet(28).to_i == 1 },
      text: "Fill the empty jug with water at the well in Cana." },
    { todo: -> { [2, 3].include?(pbGet(28).to_i) },
      text: "Bring the water back to the wine room at the wedding." },
    { todo: -> { pbGet(28).to_i == 4 },
      text: "Bring the cup of wine to the Master of the Feast." },
    { todo: -> { !$player.badges[2] }, # the Route 5 guards check badge #3 (index 2)
      text: "Earn the Prefect's Seal. The Roman guards on Route 5 won't let you pass without it." },
    { todo: -> { true },
      text: "You reached the end of the story so far! Catch Pokémon and fill your Pokédex while more is made." },
  ].freeze

  DEX = 0 # the Judea Pokédex (first regional dex)
  @last = nil
  @tick = 0

  def self.fill(text)
    rival = (pbGet(12).to_s rescue "")
    rival = "your friend" if rival.empty? || rival == "0"
    text.gsub("{rival}", rival).gsub("{player}", $player.name.to_s)
  end

  def self.goal
    STEPS.each do |s|
      done = begin
        !s[:todo].call
      rescue StandardError
        true # a step that can't be checked is skipped
      end
      return fill(s[:text]) unless done
    end
    nil
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
