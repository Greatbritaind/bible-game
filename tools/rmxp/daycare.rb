# New Nazareth Day Care interior: a first-century take on FireRed's Day Care.
# L-shaped like the building outside: the left side runs deeper, the door is on the right.
require_relative "../../stubs.rb"
src, out = ARGV
m = Marshal.load(File.binread(src))
tab = iv(m, :data); d = tab.d
w, h, z = d[4, 12].unpack("l<3")
v = Array.new(w * h * z, 0)
set = ->(l, x, y, t) { v[l * w * h + y * w + x] = t }
FLOOR, WALL_T, WALL_B, VOID = 2408, 1399, 1407, 542
room = ->(x, y) { (y <= 6 && x <= 12) || (x <= 3 && y.between?(7, 10)) }
(0...h).each { |y| (0...w).each { |x|
  if room.(x, y) then set.(0, x, y, FLOOR) else set.(1, x, y, VOID) end
} }
(0..12).each { |x| set.(1, x, 0, WALL_T); set.(1, x, 1, WALL_B) }
# door mat (exit at 8,7)
[[7, 1245], [8, 1246], [9, 1247]].each { |x, t| set.(1, x, 6, t) }
[[7, 1253], [8, 1254], [9, 1255]].each { |x, t| set.(1, x, 7, t) }

# --- the animals' corner (FireRed's little garden): a cloth shelter over straw ---
[[1, 2464], [2, 2465], [3, 2466]].each { |x, t| set.(2, x, 2, t) }
[[1, 2472], [2, 2473], [3, 2474]].each { |x, t| set.(2, x, 3, t) }
[[1, 2480], [3, 2482]].each { |x, t| set.(2, x, 4, t) }
set.(1, 2, 4, 2392); set.(1, 2, 5, 2400)          # straw bedding under the shelter
set.(2, 0, 1, 2396); set.(2, 0, 2, 2404)          # water jar beside it
set.(2, 4, 1, 2393); set.(2, 4, 2, 2401)          # basket of feed

# --- back wall: wall hanging, oven, shelves of pots (FireRed's counter and PC) ---
set.(2, 6, 0, 2397); set.(2, 6, 1, 2405)
set.(2, 8, 1, 2409); set.(2, 8, 2, 2417)          # oven
[[10, 2398], [11, 2399]].each { |x, t| set.(2, x, 1, t) }
[[10, 2406], [11, 2407]].each { |x, t| set.(2, x, 2, t) }
set.(2, 12, 1, 2414); set.(2, 12, 2, 2422)

# --- table with four seats (FireRed's table and stools) ---
# (no rug: the reed tiles read as beds)
set.(2, 9, 3, 2086); set.(2, 10, 3, 2087); set.(2, 9, 4, 2094); set.(2, 10, 4, 2095)
set.(1, 8, 3, 1682); set.(1, 8, 4, 1682); set.(1, 11, 3, 1683); set.(1, 11, 4, 1683)

# --- plants by the walls, like FireRed's ---
set.(2, 12, 5, 1772); set.(2, 12, 6, 1780)
set.(2, 5, 5, 1772); set.(2, 5, 6, 1780)

# --- sleeping corner down the deeper left side ---
set.(1, 0, 9, 2392); set.(1, 0, 10, 2400); set.(1, 1, 9, 2392); set.(1, 1, 10, 2400)
set.(2, 3, 7, 2394); set.(2, 3, 8, 2402)

tab.instance_variable_set(:@d, d[0, 20] + v.pack("s<*"))

ev = iv(m, :events)
iv(iv(ev[1], :pages)[0], :list).each { |c| iv(c, :parameters).replace([0, 112, 10, 12, 2, 1]) if iv(c, :code) == 201 }
ev[1].instance_variable_set(:@x, 8); ev[1].instance_variable_set(:@y, 7)
{ 3 => [0, 9], 4 => [0, 10], 5 => [1, 9], 6 => [1, 10] }.each { |id, (x, y)| ev[id].instance_variable_set(:@x, x); ev[id].instance_variable_set(:@y, y) }
ev[7].instance_variable_set(:@x, 6); ev[7].instance_variable_set(:@y, 4)
File.binwrite(out, Marshal.dump(m))
puts "ok"
