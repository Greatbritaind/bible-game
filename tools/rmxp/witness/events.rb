# encoding: utf-8
# Witness Case: Master of the Feast gives the cup; the messenger brings Ezra's case in Cana.
# ruby events.rb DIR   (DIR holds Map086, Map087, System; TEMPLATE_DIR has Map084 for a move route)
require File.expand_path('../stubs.rb', __dir__)
require File.expand_path('../lib.rb', __dir__)
DIR = ARGV[0]
SW = 70          # Witness Case started
VAR, VAL = 28, 5 # story progress: 5 = got the Running Sandals
B = "\\b"
def mp(n) = format('%s/Map%03d.rxdata', DIR, n)
def script(lines, ind = 0) = [cmd(355, ind, [lines[0]])] + lines[1..].map { |s| cmd(655, ind, [s]) }

sys = Marshal.load(File.binread("#{DIR}/System.rxdata"))
cur = iv(sys, :switches)[SW].to_s
raise "switch #{SW} is in use: #{cur}" unless cur.empty? || cur == 'Witness Case started'
iv(sys, :switches)[SW] = 'Witness Case started'
File.binwrite("#{DIR}/System.rxdata", Marshal.dump(sys))

# ---- Map 87: Master of the Feast
venue = Marshal.load(File.binread(mp(87)))
master = iv(venue, :events).values.find { |e| iv(e, :name) == 'Master of the Feast' } or raise 'no Master'
p2, p3 = iv(master, :pages)[1], iv(master, :pages)[2]
l2 = iv(p2, :list)
raise 'already has the cup' if l2.any? { |c| iv(c, :code) == 355 && iv(c, :parameters)[0].include?('WEDDINGCUP') }
i = l2.index { |c| iv(c, :code) == 101 && iv(c, :parameters)[0].include?('Hold the Back button') } or raise 'no sandals line'
ind = iv(l2[i], :indent)
l2.insert(i + 1, cmd(101, ind, ["#{B}Keep the cup. You'll want to remember this day."]), cmd(355, ind, ['pbAddWitness(:WEDDINGCUP)']))
# players who got the sandals before this was added still get the cup
l3 = iv(p3, :list)
l3.insert(l3.length - 1,
          cmd(111, 0, [12, '!pbHasWitness?(:WEDDINGCUP)']),
          cmd(101, 1, ["#{B}Oh! Keep the cup. You'll want to remember this day."]),
          cmd(355, 1, ['pbAddWitness(:WEDDINGCUP)']),
          cmd(0, 1, []), cmd(412, 0, []))
File.binwrite(mp(87), Marshal.dump(venue))

# ---- Map 86: Cana, the messenger
cana = Marshal.load(File.binread(mp(86)))
evs = iv(cana, :events)
raise 'messenger already there' if evs.values.any? { |e| iv(e, :name) == 'Messenger' }
TEMPLATE = evs.values.find { |e| iv(e, :pages).size == 1 } || evs.values.first
def page(gfx, list, trig: 0, var: false, sw: nil)
  pg = deep(iv(TEMPLATE, :pages)[0])
  setv(iv(pg, :condition), switch1_valid: !sw.nil?, switch1_id: sw || 1, switch2_valid: false,
       variable_valid: var, variable_id: VAR, variable_value: VAL, self_switch_valid: false)
  setv(iv(pg, :graphic), character_name: gfx, character_hue: 0, direction: 2, pattern: 0, tile_id: 0, opacity: 255, blend_type: 0)
  setv(pg, trigger: trig, move_type: 0, move_speed: 5, move_frequency: 3, walk_anime: true, step_anime: false,
       direction_fix: false, through: true, always_on_top: false)
  mr = iv(pg, :move_route); setv(mr, repeat: true, skippable: false, list: [iv(mr, :list).last])
  pg.instance_variable_set(:@list, list + [cmd(0, 0, [])]); pg
end
def add(evs, name, x, y, pages)
  id = evs.keys.max + 1; e = deep(TEMPLATE); setv(e, id: id, name: name, x: x, y: y, pages: pages); evs[id] = e; id
end
# the messenger waits out of sight in the top corner until the scene moves him
messenger = add(evs, 'Messenger', 10, 8, [page('', []), page('NPC Apprentice', [], var: true), page('', [], sw: SW)])
scene = [
  *script(["pbWitnessMessengerArrive(get_character(#{messenger}))"]),
  *script(['pbExclaim($game_player)']),
  cmd(106, 0, [16]),
  cmd(101, 0, ["#{B}Messenger: Letter for you! From Chorazin!"]),
  cmd(101, 0, ["#{B}Old Asher said you'd be somewhere in Cana."]),
  cmd(106, 0, [10]),   # a beat before the narrator reads the letter
  cmd(101, 0, ['The letter is from Ezra.']),
  cmd(101, 0, ['"Word reached me about strange things in Cana.']),
  cmd(101, 0, ['Keep what you find there. Keep anything people give you.']),
  cmd(101, 0, ['The Law says, "Don\'t forget what your eyes have seen."']),
  cmd(101, 0, ['Bring it all home to me one day. -Ezra"']),
  *script(['pbReceiveItem(:WITNESSCASE)']),
  cmd(111, 0, [12, 'pbHasWitness?(:WEDDINGCUP)']),
  cmd(101, 1, ['You put the Wedding Cup in Ezra\'s case.']),
  cmd(0, 1, []), cmd(412, 0, []),
  *script(["pbWitnessMessengerLeave(get_character(#{messenger}))"]),
  cmd(121, 0, [SW, SW, 0]),
]
runner = add(evs, 'Witness Case scene', 10, 9, [page('', []), page('', scene, trig: 3, var: true), page('', [], sw: SW)])
File.binwrite(mp(86), Marshal.dump(cana))
puts "messenger ev#{messenger}, runner ev#{runner}, switch #{SW}"
