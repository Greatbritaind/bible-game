# Minimal RPG Maker XP classes so Marshal can load and save the game's data files.
class Table
  attr_accessor :d
  def self._load(s) = new.tap { |t| t.d = s }
  def _dump(_l) = @d
end
class Color; attr_accessor :d; def self._load(s) = new.tap { |t| t.d = s }; def _dump(_l) = @d; end
class Tone;  attr_accessor :d; def self._load(s) = new.tap { |t| t.d = s }; def _dump(_l) = @d; end
module RPG
  class Map; end; class MapInfo; end; class Event; class Page; class Condition; end; class Graphic; end; end; end
  class EventCommand; end; class MoveRoute; end; class MoveCommand; end; class AudioFile; end
  class System; class Words; end; class TestBattler; end; end; class Tileset; end; class CommonEvent; end
  class Animation; class Frame; end; class Timing; end; end
end
def iv(o, k) = o.instance_variable_get(:"@#{k}")
