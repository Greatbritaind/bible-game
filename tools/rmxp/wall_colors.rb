# Gives Cana interiors tan walls and Nazareth interiors grey walls (copies of the dark Chorazin/Capernaum walls).
# The copies live in Interior General.png (tan from row 263, grey from row 273); wallmap.json maps old id -> new id.
# Usage: ruby wall_colors.rb DATA_DIR wallmap.json
require "json"
require_relative "stubs.rb"
dir, mapfile = ARGV
wm = JSON.parse(File.read(mapfile)).transform_values { |h| h.to_h { |k, v| [k.to_i, v] } }
TAN  = [87, 88, 96, 97, *98..110, 123]
GREY = [*113..117, 121, 122]

# Tileset 3: each copy gets its original's passage, priority and terrain tag.
tpath = File.join(dir, "Tilesets.rxdata")
sets = Marshal.load(File.binread(tpath))
%i[passages priorities terrain_tags].each do |k|
  t = iv(sets[3], k); d = iv(t, :d).dup
  wm.each_value { |h| h.each { |o, n| d[20 + n * 2, 2] = d[20 + o * 2, 2] } }
  t.instance_variable_set(:@d, d)
end
File.binwrite(tpath, Marshal.dump(sets))

{ "tan" => TAN, "grey" => GREY }.each do |color, maps|
  maps.each do |id|
    path = File.join(dir, format("Map%03d.rxdata", id))
    m = Marshal.load(File.binread(path))
    next puts("map #{id}: not tileset 3, skipped") unless iv(m, :tileset_id) == 3
    tab = iv(m, :data); d = iv(tab, :d)
    v = d[20..].unpack("s<*"); n = 0
    v.map! { |t| (x = wm[color][t]) ? (n += 1; x) : t }
    tab.instance_variable_set(:@d, d[0, 20] + v.pack("s<*"))
    File.binwrite(path, Marshal.dump(m))
    puts "map #{id}: #{n} tiles -> #{color}"
  end
end
