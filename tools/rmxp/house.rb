require_relative "../../stubs.rb"
dir = ARGV[0]
NEW = 123
def cmd(code, indent, params)
  c = RPG::EventCommand.new
  { code: code, indent: indent, parameters: params }.each { |k, v| c.instance_variable_set(:"@#{k}", v) }
  c
end
def say(t, i = 0) = cmd(101, i, [t])
def scr(s, i = 0) = cmd(355, i, [s])

m = Marshal.load(File.binread("#{dir}/Map104.rxdata"))
ev = iv(m, :events)
# exit back to Route 3, in front of the door
iv(iv(ev[1], :pages)[0], :list).each { |c| iv(c, :parameters).replace([0, 111, 32, 12, 2, 1]) if iv(c, :code) == 201 }
mother = ev.delete(7)

def npc(src, id, name, x, y, graphic, pages_lists)
  e = Marshal.load(Marshal.dump(src))
  e.instance_variable_set(:@id, id); e.instance_variable_set(:@name, name)
  e.instance_variable_set(:@x, x); e.instance_variable_set(:@y, y)
  base = iv(e, :pages)[0]
  pages = pages_lists.map do |list, ss|
    pg = Marshal.load(Marshal.dump(base))
    g = iv(pg, :graphic); g.instance_variable_set(:@character_name, graphic); g.instance_variable_set(:@direction, 2)
    pg.instance_variable_set(:@move_type, 0); pg.instance_variable_set(:@trigger, 0)
    c = iv(pg, :condition)
    %i[switch1_valid switch2_valid variable_valid self_switch_valid].each { |k| c.instance_variable_set(:"@#{k}", false) }
    if ss then c.instance_variable_set(:@self_switch_valid, true); c.instance_variable_set(:@self_switch_ch, ss) end
    pg.instance_variable_set(:@list, list + [cmd(0, 0, [])])
    pg
  end
  e.instance_variable_set(:@pages, pages)
  e
end

carver = [
  [[say("\\bCarver: Those six stone jars at the wedding? I carved them!"),
    say("\\bWater went in. Wine came out. In MY jars!"),
    say("\\bHere, take this. I found it at the bottom of a jar."),
    scr("pbReceiveItem(:MYSTICWATER)"),
    say("\\bGive it to a Water Pokémon. It makes Water moves stronger."),
    cmd(123, 0, ["A", 0])], nil],
  [[say("\\bCarver: Stone jars stay clean. That's why we use them for washing."),
    say("\\bClay jars crack. Stone lasts.")], "A"],
]
wife = [
  [[say("\\rWoman: The cave road to Nazareth is long and dark."),
    say("\\rWould you like your Pokémon to rest first?"),
    cmd(102, 0, [["Yes", "No"], 2]),
    cmd(402, 0, [0, "Yes"]),
    scr("pbFadeOutIn { $player.heal_party }", 1),
    say("\\rThere. All rested. Go safely.", 1),
    cmd(0, 1, []),
    cmd(402, 0, [1, "No"]),
    say("\\rCome back anytime.", 1),
    cmd(0, 1, []),
    cmd(404, 0, [])], nil],
]
ev[7] = npc(mother, 7, "Stone carver", 3, 3, "NPC Stonecutter", carver)
ev[8] = npc(mother, 8, "Carver's wife", 10, 6, "aWoman 1", wife)
m.instance_variable_set(:@autoplay_bgm, false)
File.binwrite("#{dir}/Map%03d.rxdata" % NEW, Marshal.dump(m))

# Route 3 door now opens to the new house
r = Marshal.load(File.binread("#{dir}/Map111.rxdata"))
iv(r, :events).each_value do |e|
  iv(e, :pages).each { |p| iv(p, :list).each { |c| q = iv(c, :parameters); q.replace([0, NEW, 5, 6, 8, 1]) if iv(c, :code) == 201 && q[1] == 100 } }
  e.instance_variable_set(:@name, "House door") if iv(e, :name) == "Fan club door"
end
File.binwrite("#{dir}/Map111.rxdata", Marshal.dump(r))

# Map list: new map under Route 3
infos = Marshal.load(File.binread("#{dir}/MapInfos.rxdata"))
info = Marshal.load(Marshal.dump(infos[104]))
info.instance_variable_set(:@name, "Route 3 House (Stone carver)")
info.instance_variable_set(:@parent_id, 111)
info.instance_variable_set(:@order, infos.values.map { |v| iv(v, :order) }.max + 1)
infos[NEW] = info
File.binwrite("#{dir}/MapInfos.rxdata", Marshal.dump(infos))
puts "done"
