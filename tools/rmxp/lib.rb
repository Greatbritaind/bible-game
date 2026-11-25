# encoding: utf-8
def setv(o, h) = h.each { |k, v| o.instance_variable_set(:"@#{k}", v) }
def deep(o) = Marshal.load(Marshal.dump(o))
def cmd(code, indent, params) = RPG::EventCommand.new.tap { |c| setv(c, code: code, indent: indent, parameters: params) }
def load_map(n, dir = 'game/Data') = Marshal.load(File.binread(format('%s/Map%03d.rxdata', dir, n)))
