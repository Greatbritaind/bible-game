# Turn Britain's NPC into Baruch's first scroll check (10 caught -> Amulet Coin).
# Usage: ruby baruch.rb DATA_DIR MAP_ID EVENT_ID
# Keeps the event's graphic, position and movement; replaces its pages.
require_relative "../stubs.rb"
dir, map_id, ev_id = ARGV[0], ARGV[1].to_i, ARGV[2].to_i
VAR = 30

def cmd(code, indent, params)
  c = RPG::EventCommand.new
  { code: code, indent: indent, parameters: params }.each { |k, v| c.instance_variable_set(:"@#{k}", v) }
  c
end
def say(i, t) = cmd(101, i, [t])
def script(i, s) = cmd(355, i, [s])

# --- system: name the variable ---
sys_path = File.join(dir, "System.rxdata")
sys = Marshal.load(File.binread(sys_path))
vars = iv(sys, :variables)
raise "Variable #{VAR} already used: #{vars[VAR]}" unless vars[VAR].to_s.empty? || vars[VAR] == "Scroll count"
vars[VAR] = "Scroll count"
File.binwrite(sys_path, Marshal.dump(sys))

# --- map event ---
path = File.join(dir, format("Map%03d.rxdata", map_id))
m = Marshal.load(File.binread(path))
ev = iv(m, :events)[ev_id] or raise "No event #{ev_id} on map #{map_id}"
pages = iv(ev, :pages); base = pages.find { |p| !iv(iv(p, :graphic), :character_name).to_s.empty? } || pages[0]

def check(i)
  [
    script(i, "$game_variables[#{VAR}] = $player.pokedex.owned_count"),
    cmd(111, i, [12, "$player.pokedex.owned_count >= 10"]),
    say(i + 1, "\\bYou've caught \\v[#{VAR}] kinds! Ezra will be so happy."),
    say(i + 1, "\\bHe told me to give you this."),
    script(i + 1, "pbReceiveItem(:AMULETCOIN)"),
    say(i + 1, "\\bHave a Pokémon hold it in battle."),
    say(i + 1, "\\bWin, and you'll earn twice the money!"),
    cmd(123, i + 1, ["A", 0]),
    cmd(0, i + 1, []),
    cmd(411, i, []),
    say(i + 1, "\\bYou've caught \\v[#{VAR}] kinds so far."),
    say(i + 1, "\\bCatch 10 kinds, then come find me. Ezra sent a gift!"),
    cmd(0, i + 1, []),
    cmd(412, i, []),
  ]
end

def page_from(base, list, self_sw = nil)
  pg = Marshal.load(Marshal.dump(base))
  cond = iv(pg, :condition)
  %i[switch1_valid switch2_valid variable_valid self_switch_valid].each { |k| cond.instance_variable_set(:"@#{k}", false) }
  if self_sw
    cond.instance_variable_set(:@self_switch_valid, true)
    cond.instance_variable_set(:@self_switch_ch, self_sw)
  end
  pg.instance_variable_set(:@trigger, 0)
  pg.instance_variable_set(:@list, list + [cmd(0, 0, [])])
  pg
end

first = [
  say(0, "\\bBaruch: You must be the courier! Ezra sent me."),
  say(0, "\\bI'm Baruch, Ezra's helper. I'm learning to be a scribe."),
  say(0, "\\bScribes copy Scripture by hand, one letter at a time."),
  say(0, "\\bEzra wants to see how your scroll is going."),
  cmd(123, 0, ["B", 0]),
] + check(0)

again = [
  say(0, "\\bBaruch: Back again? Let me see your scroll."),
] + check(0)

after = [
  say(0, "\\bBaruch: I travel all over Galilee. Look for me!"),
  say(0, "\\bKeep writing them down."),
]

ev.instance_variable_set(:@name, "Baruch (10 caught)")
iv(base, :graphic).instance_variable_set(:@character_name, "aBaruch")
iv(base, :graphic).instance_variable_set(:@character_hue, 0)
ev.instance_variable_set(:@pages, [page_from(base, first), page_from(base, again, "B"), page_from(base, after, "A")])
File.binwrite(path, Marshal.dump(m))
puts "Baruch set on map #{map_id} event #{ev_id} at (#{iv(ev, :x)},#{iv(ev, :y)}), graphic #{iv(iv(base, :graphic), :character_name)}"
