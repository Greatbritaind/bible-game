# Adds or replaces one plugin folder in Data/PluginScripts.rxdata.
# Usage: ruby pack_plugin.rb GAME_DIR "Plugin Name"
require "zlib"
game, name = ARGV
dir = File.join(game, "Plugins", name)
meta = { name: name, version: "1.0", essentials: ["21.1"] }
File.readlines(File.join(dir, "meta.txt"), chomp: true).each do |l|
  k, v = l.split("=", 2).map(&:strip); next unless v
  meta[:version] = v if k == "Version"
end
files = Dir.glob("**/*.rb", base: dir).sort.map { |f| [f, Zlib::Deflate.deflate(File.read(File.join(dir, f)))] }
path = File.join(game, "Data/PluginScripts.rxdata")
d = Marshal.load(File.binread(path))
i = d.index { |n, _, _| n == name }
i ? d[i] = [name, meta, files] : d << [name, meta, files]
File.binwrite(path, Marshal.dump(d))
puts "#{i ? 'replaced' : 'added'} #{name} (#{files.size} file)"
