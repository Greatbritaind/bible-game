# Plain-Ruby versions of common iterators.
#
# In Ruby compiled to WebAssembly, leaving a block early (break, return, throw) while a C-level
# iterator such as Array#each is on the stack leaks ~20 KB of WebAssembly memory every time.
# Pokémon Essentials does this thousands of times while walking, which eventually crashed the
# game. When the iterator itself is written in Ruby, these exits stay inside the Ruby VM and
# nothing leaks.

class Array
  def each
    return to_enum(:each) { size } unless block_given?
    i = 0
    while i < size
      yield self[i]
      i += 1
    end
    self
  end

  def each_with_index
    return to_enum(:each_with_index) { size } unless block_given?
    i = 0
    while i < size
      yield self[i], i
      i += 1
    end
    self
  end

  def each_index
    return to_enum(:each_index) { size } unless block_given?
    i = 0
    while i < size
      yield i
      i += 1
    end
    self
  end

  def reverse_each
    return to_enum(:reverse_each) { size } unless block_given?
    i = size - 1
    while i >= 0
      yield self[i] if i < size
      i -= 1
    end
    self
  end

  def find(ifnone = nil)
    return to_enum(:find, ifnone) unless block_given?
    i = 0
    while i < size
      v = self[i]
      return v if yield(v)
      i += 1
    end
    ifnone&.call
  end
  alias detect find

  def find_index(*args)
    return index(*args) unless args.empty?
    return to_enum(:find_index) unless block_given?
    i = 0
    while i < size
      return i if yield(self[i])
      i += 1
    end
    nil
  end

  def any?(*args)
    return super unless block_given? && args.empty?
    i = 0
    while i < size
      return true if yield(self[i])
      i += 1
    end
    false
  end

  def all?(*args)
    return super unless block_given? && args.empty?
    i = 0
    while i < size
      return false unless yield(self[i])
      i += 1
    end
    true
  end

  def none?(*args)
    return super unless block_given? && args.empty?
    i = 0
    while i < size
      return false if yield(self[i])
      i += 1
    end
    true
  end

  def map
    return to_enum(:map) { size } unless block_given?
    out = Array.new(size)
    i = 0
    while i < size
      out[i] = yield(self[i])
      i += 1
    end
    out
  end
  alias collect map

  def select
    return to_enum(:select) { size } unless block_given?
    out = []
    i = 0
    while i < size
      v = self[i]
      out << v if yield(v)
      i += 1
    end
    out
  end
  alias filter select

  def reject
    return to_enum(:reject) { size } unless block_given?
    out = []
    i = 0
    while i < size
      v = self[i]
      out << v unless yield(v)
      i += 1
    end
    out
  end
end

class Hash
  def each
    return to_enum(:each) { size } unless block_given?
    ks = keys
    i = 0
    while i < ks.size
      k = ks[i]
      yield [k, self[k]] if key?(k)
      i += 1
    end
    self
  end
  alias each_pair each

  def each_key
    return to_enum(:each_key) { size } unless block_given?
    ks = keys
    i = 0
    while i < ks.size
      yield ks[i]
      i += 1
    end
    self
  end

  def each_value
    return to_enum(:each_value) { size } unless block_given?
    ks = keys
    i = 0
    while i < ks.size
      yield self[ks[i]] if key?(ks[i])
      i += 1
    end
    self
  end
end

class Integer
  def times
    return to_enum(:times) { self < 0 ? 0 : self } unless block_given?
    i = 0
    while i < self
      yield i
      i += 1
    end
    self
  end

  def upto(limit)
    return to_enum(:upto, limit) unless block_given?
    i = self
    while i <= limit
      yield i
      i += 1
    end
    self
  end

  def downto(limit)
    return to_enum(:downto, limit) unless block_given?
    i = self
    while i >= limit
      yield i
      i -= 1
    end
    self
  end
end

class Range
  alias rgss_c_each each

  def each(&block)
    return to_enum(:each) unless block
    b = self.begin
    e = self.end
    if b.is_a?(Integer) && (e.is_a?(Integer) || e.nil?)
      i = b
      if e.nil?
        loop do
          yield i
          i += 1
        end
      else
        last = exclude_end? ? e - 1 : e
        while i <= last
          yield i
          i += 1
        end
      end
      self
    else
      rgss_c_each(&block)
    end
  end
end
