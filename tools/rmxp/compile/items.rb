# Add any items in PBS/items.txt that are missing from Data/items.dat (or rebuild changed simple ones).
# Usage: ruby items.rb GAME_DIR
module GameData; class Item; end; end
game = ARGV[0]
dat = File.join(game, "Data/items.dat")
d = Marshal.load(File.binread(dat))
FU = { "OnPokemon" => 1, "Direct" => 2, "TR" => 3, "TM" => 4, "HM" => 5 }
BU = { "OnPokemon" => 1, "OnMove" => 2, "OnBattler" => 3, "OnFoe" => 4, "Direct" => 5 }
txt = File.read(File.join(game, "PBS/items.txt"), encoding: "bom|utf-8")
added = []
txt.split(/^\[/)[1..].each do |sec|
  id = sec[/\A([A-Z0-9_]+)\]/, 1].to_sym
  next if d.key?(id)
  h = {}
  sec.each_line { |l| h[$1] = $2.strip if l =~ /^(\w+)\s*=\s*(.*)$/ }
  flags = (h["Flags"] || "").split(",").map(&:strip)
  price = (h["Price"] || 0).to_i
  it = GameData::Item.allocate
  {
    id: id, real_name: h["Name"], real_name_plural: h["NamePlural"] || h["Name"],
    real_portion_name: h["PortionName"], real_portion_name_plural: h["PortionNamePlural"],
    pocket: (h["Pocket"] || 1).to_i, price: price, sell_price: (h["SellPrice"] || price / 2).to_i,
    bp_price: (h["BPPrice"] || 1).to_i, field_use: FU[h["FieldUse"]] || 0, battle_use: BU[h["BattleUse"]] || 0,
    flags: flags, consumable: h.key?("Consumable") ? h["Consumable"] =~ /true/i ? true : false : !flags.include?("KeyItem") && !%w[TM HM].include?(h["FieldUse"]),
    show_quantity: nil, move: h["Move"]&.to_sym, real_description: h["Description"], pbs_file_suffix: ""
  }.each { |k, v| it.instance_variable_set(:"@#{k}", v) }
  d[id] = it
  added << id
end
File.binwrite(dat, Marshal.dump(d))
puts "Added: #{added.inspect}"
