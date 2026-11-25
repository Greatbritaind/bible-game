# Route 3 (map 111) wild Pokémon, plus the Strength patch (Secret list) east of the boulder.
# Usage: ruby route3_encounters.rb GAME_DIR
require_relative "stubs.rb"
module GameData; class Encounter; end; end
game = ARGV[0]
MAP = 111
LAND = [[25, :BELLSPROUT, 12, 14], [20, :MEOWTH, 12, 14], [15, :VENONAT, 12, 15], [15, :SANDSHREW, 12, 15],
        [10, :JIGGLYPUFF, 13, 15], [10, :MACHOP, 13, 15], [5, :GROWLITHE, 14, 15]]
SECRET = [[50, :TAUROS, 15, 17], [50, :PINSIR, 15, 17]]
PATCH = [35, 26, 4, 16]   # x, y, width, height of the grass behind the boulder

# --- PBS/encounters.txt ---
pbs = File.join(game, "PBS/encounters.txt")
raw = File.binread(pbs); bom = raw.start_with?("\xEF\xBB\xBF".b)
txt = File.read(pbs, encoding: "bom|utf-8")
line = ->(e) { "    #{e[0]},#{e[1]},#{e[2]},#{e[3]}" }
block = "#-------------------------------\n[#{format('%03d', MAP)}] # Route 3\nLand,21\n" +
        LAND.map(&line).join("\n") + "\nSecret,21\n" + SECRET.map(&line).join("\n") + "\n"
txt = txt.sub(/#-+\n\[#{format('%03d', MAP)}\][^\[]*/m, "")
File.write(pbs, (bom ? "\uFEFF" : "") + txt.rstrip + "\n" + block)

# --- Data/encounters.dat ---
dat = File.join(game, "Data/encounters.dat")
d = Marshal.load(File.binread(dat))
e = GameData::Encounter.allocate
key = :"#{MAP}_0"
{ id: key, map: MAP, version: 0, step_chances: { Land: 21, Secret: 21 },
  types: { Land: LAND, Secret: SECRET }, pbs_file_suffix: "" }.each { |k, v| e.instance_variable_set(:"@#{k}", v) }
d[key] = e
File.binwrite(dat, Marshal.dump(d))

# --- SecretGrass event over the patch ---
path = File.join(game, format("Data/Map%03d.rxdata", MAP))
m = Marshal.load(File.binread(path))
evs = iv(m, :events)
x, y, w, h = PATCH
name = "SecretGrass size(#{w},#{h})"
old = evs.values.find { |ev| iv(ev, :name).to_s =~ /SecretGrass/i }
id = old ? iv(old, :id) : evs.keys.max + 1
ev = Marshal.load(Marshal.dump(evs[16]))   # the sign: a blank event to copy
{ id: id, name: name, x: x, y: y }.each { |k, v| ev.instance_variable_set(:"@#{k}", v) }
pg = iv(ev, :pages)[0]
iv(pg, :graphic).instance_variable_set(:@character_name, "")
iv(pg, :graphic).instance_variable_set(:@tile_id, 0)
pg.instance_variable_set(:@through, true)
pg.instance_variable_set(:@list, [iv(pg, :list).last])
ev.instance_variable_set(:@pages, [pg])
evs[id] = ev
File.binwrite(path, Marshal.dump(m))
puts "Route 3 encounters set; #{name} is ev#{id} at (#{x},#{y})"
