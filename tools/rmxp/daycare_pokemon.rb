# Day Care Pokémon: two in the pen inside (map 114), two in the fenced yard behind the house (map 112),
# and a sign by the Day Care door. Usage: ruby daycare_pokemon.rb DATA_DIR
require_relative "stubs.rb"
dir = ARGV[0]

def cmd(code, indent, params)
  c = RPG::EventCommand.new
  { code: code, indent: indent, parameters: params }.each { |k, v| c.instance_variable_set(:"@#{k}", v) }
  c
end

# New event cloned from a template event, with one page.
def new_event(m, tmpl, name, x, y, list, graphic: "", move: 0, step: false)
  evs = iv(m, :events)
  old = evs.values.find { |e| iv(e, :name) == name }
  id = old ? iv(old, :id) : (evs.keys.max || 0) + 1
  e = Marshal.load(Marshal.dump(tmpl))
  { id: id, name: name, x: x, y: y }.each { |k, v| e.instance_variable_set(:"@#{k}", v) }
  pg = Marshal.load(Marshal.dump(iv(tmpl, :pages)[0]))
  c = iv(pg, :condition)
  %i[switch1_valid switch2_valid variable_valid self_switch_valid].each { |k| c.instance_variable_set(:"@#{k}", false) }
  g = iv(pg, :graphic)
  { character_name: graphic, character_hue: 0, direction: 2, pattern: 0, tile_id: 0, opacity: 255, blend_type: 0 }.each { |k, v| g.instance_variable_set(:"@#{k}", v) }
  { move_type: move, move_frequency: 3, move_speed: 2, walk_anime: true, step_anime: step, direction_fix: false,
    through: false, always_on_top: false, trigger: 0, list: list + [cmd(0, 0, [])] }.each { |k, v| pg.instance_variable_set(:"@#{k}", v) }
  e.instance_variable_set(:@pages, [pg])
  evs[id] = e
  puts "#{name}: ev#{id} (#{x},#{y})"
end

def mon(m, tmpl, sp, x, y, line)
  new_event(m, tmpl, "Day Care #{sp.capitalize}", x, y,
            [cmd(355, 0, ["Pokemon.play_cry(:#{sp})"]), cmd(101, 0, [line])],
            graphic: "Followers/#{sp}", move: 1, step: true)
end

def load_map(dir, n) = Marshal.load(File.binread(File.join(dir, format("Map%03d.rxdata", n))))
def save_map(dir, n, m) = File.binwrite(File.join(dir, format("Map%03d.rxdata", n)), Marshal.dump(m))

# --- inside: the pen (x1-3, y2-4) ---
m = load_map(dir, 114)
tmpl = iv(m, :events)[7]
mon(m, tmpl, "MAREEP", 1, 3, "Mareep is napping in the straw.")
mon(m, tmpl, "PONYTA", 3, 4, "Ponyta stamps its hooves. It wants to run!")
save_map(dir, 114, m)

# --- outside: the yard behind the house, and the sign ---
m = load_map(dir, 112)
tmpl = iv(m, :events)[3]
mon(m, tmpl, "MILTANK", 8, 6, "Miltank is chewing slowly. It looks happy.")
mon(m, tmpl, "DODUO", 13, 7, "Doduo's two heads are arguing again.")
new_event(m, tmpl, "Day Care sign", 9, 12,
          [cmd(101, 0, ["NAZARETH DAY CARE\nWe'll care for your Pokémon."])])
# signpost tile under the sign event (the wooden post used for the cliff sign)
d = iv(iv(m, :data), :d); w, h = d[4, 8].unpack("l<2")
v = d[20..].unpack("s<*"); v[2 * w * h + 12 * w + 9] = 1337
iv(m, :data).instance_variable_set(:@d, d[0, 20] + v.pack("s<*"))
save_map(dir, 112, m)
