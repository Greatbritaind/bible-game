# Starts the game the way RPG Maker XP does: run every script section in Data/Scripts.rxdata in order.
Dir.chdir("/game")

$DEBUG = false
$TEST = false
$BTEST = false

begin
  $RGSS_SCRIPTS = load_data("Data/Scripts.rxdata")
  $RGSS_SCRIPTS.each_with_index do |section, i|
    code = Zlib::Inflate.inflate(section[2]).force_encoding(Encoding::UTF_8)
    section[3] = code
    RGSSRuntime.call(:loading, i + 1, $RGSS_SCRIPTS.size, section[1].to_s)
    RGSSRuntime.await(:next_frame) if i % 40 == 0
    # "SectionNNN" lets Essentials' error messages show the script's name
    before = Object.private_instance_methods(false)
    eval(code, TOPLEVEL_BINDING, format("Section%03d", i))
    # RPG Maker makes top-level functions public (scripts call e.g. Kernel.pbShowCommands)
    added = Object.private_instance_methods(false) - before
    Object.send(:public, *added) unless added.empty?
  end
  RGSSRuntime.call(:game_ended)
rescue SystemExit
  RGSSRuntime.call(:game_ended)
rescue Exception => e
  lines = [(e.backtrace || []).first(12).map do |l|
    l.gsub(/Section(\d+)/) { "#{$RGSS_SCRIPTS[$1.to_i][1] rescue $1}" }
  end].flatten
  RGSSRuntime.call(:fatal, "#{e.class}: #{e.message}", lines.join("\n"))
end
