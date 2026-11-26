# Battle positions for the 8 newer Pokémon (front offset worked out from each sprite's empty space).
# Usage: ruby newmon_metrics.rb GAME_DIR
module GameData; class SpeciesMetrics; end; end
game = ARGV[0]
M = { SKIDDO: [0, 25, 2], GOGOAT: [0, 18, 2], LITLEO: [0, 27, 2], PYROAR: [0, 13, 3], MUDBRAY: [1, 22, 2],
      MUDSDALE: [1, 16, 3], WOOLOO: [2, 28, 2], DUBWOOL: [0, 13, 3] }
pbs = File.join(game, "PBS/pokemon_metrics.txt")
txt = File.read(pbs, encoding: "bom|utf-8")
dat = File.join(game, "Data/species_metrics.dat")
d = Marshal.load(File.binread(dat))
M.each do |sp, (x, y, sh)|
  txt = txt.sub(/#-+\n\[#{sp}\]\n(?:[^\[#].*\n)*/, "")
  txt = txt.rstrip + "\n#-------------------------------\n[#{sp}]\nBackSprite = 0,0\nFrontSprite = #{x},#{y}\nShadowX = 0\nShadowSize = #{sh}\n"
  e = GameData::SpeciesMetrics.allocate
  { id: sp, species: sp, form: 0, back_sprite: [0, 0], front_sprite: [x, y], front_sprite_altitude: 0,
    shadow_x: 0, shadow_size: sh, pbs_file_suffix: "" }.each { |k, v| e.instance_variable_set(:"@#{k}", v) }
  d[sp] = e
end
File.write(pbs, "﻿" + txt)
File.binwrite(dat, Marshal.dump(d))
puts "metrics for #{M.keys.join(', ')}"
