# Nain + Route 4 event builder.
# Britain places events on her maps and names them as listed in RULES below (graphic and spot are hers).
# This script fills in each event's pages by name and keeps her graphic, spot and movement.
#
# Usage: ruby nain.rb DATA_DIR MAP_ID [MAP_ID ...]
#   Applies to every event whose name matches a rule. Prints which rules it used.
require_relative "../stubs.rb"

SW_ARRIVED = 71   # "Nain arrival seen"

def cmd(code, indent, params)
  c = RPG::EventCommand.new
  { code: code, indent: indent, parameters: params }.each { |k, v| c.instance_variable_set(:"@#{k}", v) }
  c
end
def say(t, i = 0) = cmd(101, i, [t])
def scr(s, i = 0) = cmd(355, i, [s])
def wait(f, i = 0) = cmd(106, i, [f])
def self_sw(ch, i = 0) = cmd(123, i, [ch, 0])
def sw_on(id, i = 0) = cmd(121, i, [id, id, 0])
def iff(script, i = 0) = cmd(111, i, [12, script])
def els(i = 0) = cmd(411, i, [])
def endif(i = 0) = cmd(412, i, [])
def blank(i) = cmd(0, i, [])

# A page built from the event's first page (keeps graphic, move type, etc.)
def page(base, list, trigger: 0, self_sw: nil, switch: nil, graphic: :keep, through: nil)
  pg = Marshal.load(Marshal.dump(base))
  c = iv(pg, :condition)
  %i[switch1_valid switch2_valid variable_valid self_switch_valid].each { |k| c.instance_variable_set(:"@#{k}", false) }
  if self_sw
    c.instance_variable_set(:@self_switch_valid, true); c.instance_variable_set(:@self_switch_ch, self_sw)
  end
  if switch
    c.instance_variable_set(:@switch1_valid, true); c.instance_variable_set(:@switch1_id, switch)
  end
  if graphic == :none
    g = iv(pg, :graphic); g.instance_variable_set(:@character_name, ""); g.instance_variable_set(:@tile_id, 0)
  end
  pg.instance_variable_set(:@through, through) unless through.nil?
  pg.instance_variable_set(:@trigger, trigger)
  pg.instance_variable_set(:@list, list + [blank(0)])
  pg
end

# Simple talker: lines, then (optional) different lines once the arrival scene is done.
def talker(lines) = ->(ev, base) { [page(base, lines.map { |l| say(l) })] }

# Gives something once, then says the "after" lines.
def giver(first, give, after)
  ->(ev, base) {
    [page(base, first.map { |l| say(l) } + give + [self_sw("A")]),
     page(base, after.map { |l| say(l) }, self_sw: "A")]
  }
end

# Trainer event, same shape as Britain's other trainers.
def trainer(klass, name, intro, after)
  ->(ev, base) {
    ev.instance_variable_set(:@name, "Trainer(3) #{name}")
    [page(base, [scr("pbTrainerIntro(:#{klass})"), scr("pbNoticePlayer(get_self)")] + intro.map { |l| say(l) } +
                [iff("TrainerBattle.start(:#{klass}, \"#{name}\")"), self_sw("A", 1), blank(1), endif, scr("pbTrainerEnd")],
          trigger: 2),
     page(base, after.map { |l| say(l) }, self_sw: "A")]
  }
end

# Crowd at the gate: there until the scene ends, then gone.
CROWD = ->(ev, base) { [page(base, []), page(base, [], switch: SW_ARRIVED, graphic: :none, through: true)] }

# The gate scene. Each "Gate trigger" tile starts it the first time the player steps on one.
GATE_SCENE = ->(ev, base) {
  list = [
    scr("pbExclaim($game_player)"), wait(16),
    scr("$game_map.events.each_value { |e| e.turn_toward_player if e.name.start_with?(\"Gate:\") }"),
    say("\\bMan: He was dead! We were carrying him out to bury him!"),
    say("\\rWoman: The teacher told her, \"Don't cry.\""),
    say("\\rThen he touched the stretcher, and we all stopped."),
    say("\\bOld man: He said, \"Young man, get up!\" And he did!"),
    say("\\rWoman: A great prophet has come to us!"),
    say("\\bMan: God has come to help his people!"),
    wait(10),
    # Fade out, clear the crowd (mother and son go home), fade back in.
    scr("pbFadeOutIn { $game_switches[#{SW_ARRIVED}] = true; $game_map.refresh }"),
  ]
  [page(base, list, trigger: 1, graphic: :none, through: true),
   page(base, [], switch: SW_ARRIVED, graphic: :none, through: true)]
}

RULES = {
  # ---------------- Route 4 ----------------
  "Running man" => ->(ev, base) {
    # Steps aside, then runs past toward Nazareth (west) after the player bumps into or talks to him.
    run = "pbMoveRoute(get_self, [PBMoveRoute::CHANGE_SPEED, 5] + [PBMoveRoute::UP] + [PBMoveRoute::LEFT] * 12 + [PBMoveRoute::OPACITY, 0], true)"
    [page(base, [scr("pbExclaim(get_self)"), wait(10), scr("get_self.turn_toward_player"),
                 say("\\bMan: You're going to Nain? Go! Go and see!"),
                 say("\\bI have to tell my brother. He won't believe me."),
                 scr(run), cmd(210, 0, []), self_sw("A")], trigger: 1),
     page(base, [], self_sw: "A", graphic: :none, through: true)]
  },
  "Tabor sign" => talker(["Mount Tabor, to the north."]),
  "Spring woman" => talker(["\\rWoman: This spring never runs dry.",
                            "\\rRest a bit. Nain is just across the valley."]),
  "Trainer Elon" => trainer("SHEPHERD", "Elon",
    ["\\bElon: My flock runs all over this valley!", "\\bLet's see if you can keep up."],
    ["\\bElon: Too fast for me. Nain is just ahead."]),
  "Trainer Keziah" => trainer("SPICETRADER", "Keziah",
    ["\\rKeziah: I'm taking spices to Nain.", "\\rBattle me first!"],
    ["\\rKeziah: Spicy! You win this one."]),
  "Trainer Shimei" => trainer("TENTMAKER", "Shimei",
    ["\\bShimei: My tent is set up by the spring.", "\\bWe can rest after we battle!"],
    ["\\bShimei: Time for that rest. Good luck in Nain!"]),
  "Trainer Elkanah" => trainer("ELDER", "Elkanah",
    ["\\bElkanah: I've walked this road all my life.", "\\bShow me what you've learned!"],
    ["\\bElkanah: You're stronger than these old legs."]),

  # ---------------- Nain: the gate ----------------
  "Gate trigger" => GATE_SCENE,
  "Gate: man" => CROWD, "Gate: woman" => CROWD, "Gate: old man" => CROWD,
  "Gate: woman 2" => CROWD, "Gate: man 2" => CROWD, "Gate: mother" => CROWD,
  "Gate: son" => CROWD, "Gate: stretcher" => CROWD, "Gate: crowd" => CROWD,

  # ---------------- Nain: outside ----------------
  "Messenger 1" => talker(["\\bMessenger: John the Baptist sent us. He's in prison.",
                           "\\bHe wants to ask the teacher, \"Are you the one?\""]),
  "Messenger 2" => talker(["\\bMessenger: We heard he was here. Did we miss him again?"]),
  "Water woman" => talker(["\\rWoman: We were all crying an hour ago.",
                           "\\rNow the whole town is laughing. I can't stop shaking."]),
  "Tomb boy" => talker(["\\bBoy: Don't go to the tombs! Something spooky lives there.",
                        "\\bNormal moves go right through it. I tried!"]),
  # The son walks around town once the scene is over, getting used to being alive.
  "Son" => ->(ev, base) {
    [page(base, [], graphic: :none, through: true),
     page(base, [say("\\bSon: I was wrapped in this an hour ago."),
                 say("\\bI don't need it anymore. Take it."),
                 scr("pbAddWitness(:BURIALCLOTH)"), self_sw("A")], switch: SW_ARRIVED),
     page(base, [say("\\bSon: The sun feels so warm today."),
                 say("\\bHave you ever noticed that?")], self_sw: "A")]
  },

  # ---------------- Nain: houses ----------------
  "Widow" => giver(
    ["\\rMother: My husband died. Then my only son.",
     "\\rI had no one left. And now... look at him.",
     "\\rPlease, take this. It helps a Pokémon grow, even resting."],
    [scr("pbReceiveItem(:EXPSHARE)")],
    ["\\rMother: He's out walking. He keeps touching everything.",
     "\\rLike he's seeing it all for the first time."]),
  "Mourner" => talker(["\\rMourner: I was paid to cry at the funeral.",
                       "\\rNow there's no funeral. What do I do?",
                       "\\rShould I give the money back?"]),
  "Carrier" => talker(["\\bCarrier: I was carrying him. My arms were tired.",
                       "\\bThen the teacher touched the stretcher, and we just... stopped."]),
  "Elisha man" => talker(["\\bOld man: Long ago, Elisha raised a boy back to life.",
                          "\\bAt Shunem, just over that hill.",
                          "\\bToday it happened again, here. Who is this man?"]),
  "Feast woman" => giver(
    ["\\rWoman: The funeral food is still here.",
     "\\rSo now it's a feast! Want some bread?"],
    [scr("pbReceiveItem(:POTION, 2)")],
    ["\\rWoman: Eat up! Today is a feast day."]),

  # ---------------- Nain: synagogue (copy of another synagogue; the Rabbi comes with it) ----------------
  "Verse left" => talker(["\"A father to the fatherless, a defender of widows, is God.\"", "Psalm 68:5"]),
  "Verse right" => talker(["\"You turned my mourning into dancing.\"", "Psalm 30:11"]),

  # ---------------- The tombs ----------------
  "Empty tomb" => talker(["This tomb was cut for the widow's son.", "It was never used."]),
}

dir = ARGV.shift
sys_path = File.join(dir, "System.rxdata")
sys = Marshal.load(File.binread(sys_path))
sws = iv(sys, :switches)
raise "Switch #{SW_ARRIVED} in use: #{sws[SW_ARRIVED]}" unless sws[SW_ARRIVED].to_s.empty? || sws[SW_ARRIVED] == "Nain arrival seen"
sws[SW_ARRIVED] = "Nain arrival seen"
File.binwrite(sys_path, Marshal.dump(sys))

used = []
ARGV.map(&:to_i).each do |map_id|
  path = File.join(dir, format("Map%03d.rxdata", map_id))
  m = Marshal.load(File.binread(path))
  iv(m, :events).each do |id, ev|
    name = iv(ev, :name).to_s.sub(/\ATrainer\(\d+\)\s*/, "Trainer ")
    rule = RULES[name] or next
    pages = iv(ev, :pages); base = pages.find { |p| !iv(iv(p, :graphic), :character_name).to_s.empty? } || pages[0]
    ev.instance_variable_set(:@pages, rule.call(ev, base))
    used << name
    puts "map #{map_id} ev#{id} #{name} (#{iv(ev, :x)},#{iv(ev, :y)})"
  end
  File.binwrite(path, Marshal.dump(m))
end
missing = RULES.keys - used
puts "Not found yet: #{missing.join(', ')}" unless missing.empty?
