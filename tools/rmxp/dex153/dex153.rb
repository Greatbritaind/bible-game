# The 153 regional Pokédex (John 21:11) and the team/wild changes that go with it.
# Edits PBS text and the compiled Data files together. Usage: ruby dex153.rb GAME_DIR
module GameData; class Trainer; end; class Encounter; end; end
G = ARGV[0]
def pbs_read(f) = File.read(File.join(G, "PBS", f), encoding: "bom|utf-8")
def pbs_write(f, t) = File.write(File.join(G, "PBS", f), "﻿" + t.sub(/\A﻿/, ""))
def dat(f) = File.join(G, "Data", f)

DEX = File.read(File.join(__dir__, "list.txt")).strip.split(",").map(&:to_sym)
raise "need 153, got #{DEX.size}" unless DEX.size == 153 && DEX.uniq.size == 153

# ---- regional dex 0 = Ezra's Scroll ----
t = pbs_read("regional_dexes.txt")
t = t.gsub("\r\n", "\n").sub(/\[0\]\n(?:[^\[#].*\n?)*/, "[0]\n" + DEX.each_slice(8).map { |s| s.join(",") }.join("\n") + "\n")
pbs_write("regional_dexes.txt", t)
d = Marshal.load(File.binread(dat("regional_dexes.dat"))); d[0] = DEX
File.binwrite(dat("regional_dexes.dat"), Marshal.dump(d))

# ---- trainers: same levels, new species ----
TEAMS = {
  "LEADER_Hannah,Hannah" => [[:BELLSPROUT, 12], [:PETILIL, 13], [:SKIDDO, 14]],
  "APPRENTICE,Boaz" => [[:GEODUDE, 15], [:ROGGENROLA, 15]],
  "STONECUTTERF,Abigail" => [[:ROGGENROLA, 16]],
  "ELDER,Amos" => [[:RHYHORN, 17], [:GEODUDE, 17]],
  "ZEALOT,Simeon" => [[:MANKEY, 17], [:SKORUPI, 17]],
  "ZEALOT,Ezer" => [[:MANKEY, 10], [:SKORUPI, 10]],
  "SHEPHERD,Caleb" => [[:MAREEP, 14], [:WOOLOO, 14]],
  "BAKER,Seth" => [[:LILLIPUP, 14]],
  "WEAVER,Mara" => [[:PETILIL, 14], [:COMBEE, 15]],
  "TENTMAKER,Levi" => [[:SKIDDO, 15]],
  "ELDER_F,Hulda" => [[:MILTANK, 15]],
  "LITTLEGIRL1,Talia" => [[:PIDOVE, 13], [:PICHU, 14]],
  "PHARISEE,Joel" => [[:DROWZEE, 15]],
  "SPICETRADER,Adina" => [[:NUMEL, 15]],
  "ELDER,Omri" => [[:MACHOP, 15], [:TAUROS, 15]],
  "ROMANSOLDIER,Marcus" => [[:LILLIPUP, 6], [:RATTATA, 6]],
  "PHARISEE,Eliab" => [[:EEVEE, 12], [:DROWZEE, 13]],
  "SHEPHERD,Gad" => [[:ODDISH, 10], [:PETILIL, 10]],
  "SPICETRADER,Tirzah" => [[:BELLSPROUT, 11], [:ODDISH, 12]],
  "WEAVER,Judith" => [[:PARAS, 18], [:BUTTERFREE, 18]],
}
t = pbs_read("trainers.txt")
td = Marshal.load(File.binread(dat("trainers.dat")))
TEAMS.each do |key, team|
  re = /^\[#{Regexp.escape(key)}\]\n((?:(?!#|\[).*\n)*)/
  m = t.match(re) or raise "trainer #{key} not in PBS"
  head = m[1].lines.take_while { |l| l !~ /^Pokemon\s*=/ }.join
  t = t.sub(re) { "[#{key}]\n" + head + team.map { |s, l| "Pokemon = #{s},#{l}\n" }.join }
  type, name = key.split(","); id = [type.to_sym, name, 0]
  td[id] or raise "trainer #{key} not in trainers.dat"
  td[id].instance_variable_set(:@pokemon, team.map { |s, l| { species: s, level: l } })
end
pbs_write("trainers.txt", t)
File.binwrite(dat("trainers.dat"), Marshal.dump(td))

# ---- wild Pokémon ----
WILD = {
  78 => "Route 1\nLand,21\n    35,PIDGEY,2,4\n    35,RATTATA,2,4\n    20,PIDOVE,2,4\n    5,MANKEY,3,4\n    5,NIDORANfE,3,4\n",
  85 => "Route 2\nLand,21\n    25,PIDGEY,3,5\n    20,RATTATA,3,5\n    15,MAREEP,3,5\n    15,WOOLOO,3,5\n    10,NIDORANfE,3,5\n    10,NIDORANmA,3,5\n    5,MANKEY,4,5\nSecret,21\n    100,EEVEE,10,12\n",
  84 => "Arbel Forest\nLand,21\n    25,CATERPIE,4,6\n    25,WEEDLE,4,6\n    15,COMBEE,4,6\n    10,METAPOD,5,6\n    10,KAKUNA,5,6\n    5,ODDISH,4,6\n    5,PIKACHU,6,7\n    5,ZORUA,6,7\n",
  120 => "Nazareth Caves\nCave,10\n    35,ZUBAT,15,17\n    30,GEODUDE,15,18\n    15,PARAS,15,17\n    10,ROGGENROLA,16,18\n    5,ONIX,17\n    5,CLEFAIRY,16\nWater,10\n    50,MAGIKARP,22,26\n    40,GOLDEEN,22,25\n    10,FEEBAS,20,22\n",
  111 => "Route 3\nLand,21\n    25,BELLSPROUT,12,14\n    20,LILLIPUP,12,14\n    15,SANDSHREW,12,15\n    15,SKIDDO,12,15\n    10,PETILIL,13,15\n    10,MACHOP,13,15\n    5,GROWLITHE,14,15\nSecret,21\n    50,TAUROS,15,17\n    50,BOUFFALANT,15,17\n",
}
t = pbs_read("encounters.txt")
ed = Marshal.load(File.binread(dat("encounters.dat")))
WILD.each do |map, body|
  id = format("%03d", map)
  block = "[#{id}] # #{body}"
  re = /^\[#{id}\][^\n]*\n(?:(?!#|\[).*\n)*/
  t =~ re or raise "map #{id} not in encounters.txt"
  t = t.sub(re) { block + "\n" }
  steps = {}; types = {}; cur = nil
  body.lines.drop(1).each do |l|
    if l =~ /^(\w+),(\d+)/ then cur = $1.to_sym; steps[cur] = $2.to_i; types[cur] = []
    elsif l =~ /^\s+(\d+),(\w+),(\d+)(?:,(\d+))?/ then types[cur] << [$1.to_i, $2.to_sym, $3.to_i, ($4 || $3).to_i]
    end
  end
  types.each_value { |a| a.sort_by! { |e| -e[0] } }
  key = :"#{map}_0"
  e = ed[key] || GameData::Encounter.allocate
  { id: key, map: map, version: 0, step_chances: steps, types: types, pbs_file_suffix: "" }.each { |k, v| e.instance_variable_set(:"@#{k}", v) }
  ed[key] = e
end
pbs_write("encounters.txt", t)
File.binwrite(dat("encounters.dat"), Marshal.dump(ed))

# ---- check: nothing outside the 153 in these maps or teams ----
bad = TEAMS.values.flatten(1).map(&:first).reject { |s| DEX.include?(s) } +
      WILD.keys.flat_map { |m| ed[:"#{m}_0"].instance_variable_get(:@types).values.flatten(1).map { |e| e[1] } }.reject { |s| DEX.include?(s) }
raise "not in the 153: #{bad.uniq}" unless bad.empty?
puts "Ezra's Scroll: #{DEX.size} Pokémon; #{TEAMS.size} trainers; wild on maps #{WILD.keys.join(', ')}"
