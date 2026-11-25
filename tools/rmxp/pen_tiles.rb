# Gives the copied fence-post tiles (Interior General row 290) the same passage/priority/terrain as their Outside originals.
require_relative "stubs.rb"
path = ARGV[0]
sets = Marshal.load(File.binread(path))
outside, inside = sets[1], sets[3]
PAIRS = { 2704 => [4, 165], 2705 => [3, 165], 2706 => [5, 165], 2707 => [6, 165], 2708 => [5, 166] }
%i[passages priorities terrain_tags].each do |k|
  src = iv(outside, k); dst = iv(inside, k)
  sd = iv(src, :d); dd = iv(dst, :d)
  sx = sd[4, 4].unpack1("l<"); dx = dd[4, 4].unpack1("l<")
  raise "table too small" if dx <= PAIRS.keys.max
  PAIRS.each do |id, (c, r)|
    oid = 384 + r * 8 + c
    val = sd[20 + oid * 2, 2]
    dd[20 + id * 2, 2] = val
    puts "#{k} #{id} <- #{oid}: #{val.unpack1('s<')}"
  end
  dst.instance_variable_set(:@d, dd)
end
File.binwrite(path, Marshal.dump(sets))
