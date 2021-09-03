require 'tempfile'

module CoreExtensions

# STRING ##########################################################################################

module String
  # https://en.wikipedia.org/wiki/Whitespace_character#Unicode
  SPACE_CHAR_CLASS = '\p{Space}\u180e\u200b\u200c\u200d\u2060\ufeff'.freeze
  LSTRIP_SPACE_REGEX = %r{\A[#{SPACE_CHAR_CLASS}]+}.freeze
  RSTRIP_SPACE_REGEX = %r{[#{SPACE_CHAR_CLASS}]+\z}.freeze

  def lstrip
    (encoding == Encoding::UTF_8) ? sub(LSTRIP_SPACE_REGEX, '') : super
  end

  def rstrip
    (encoding == Encoding::UTF_8) ? sub(RSTRIP_SPACE_REGEX, '') : super
  end

  def strip
    if encoding == Encoding::UTF_8
      dup.tap do |str|
        str.sub!(LSTRIP_SPACE_REGEX, '')
        str.sub!(RSTRIP_SPACE_REGEX, '')
      end
    else
      super
    end
  end

  def possessive
    str = self + "'"
    str += 's' unless %r{(s|se|z|ze|ce|x|xe)$}i.match(self)
    str
  end

  def force_utf8
    if (encoding == Encoding::UTF_8) && valid_encoding?
      self
    else
      encode('utf-8', invalid: :replace, undef: :replace)
    end
  end

  def to_hex
    self.b.unpack('H*').first
  end
end

# ARRAY ###########################################################################################

module Array
  def except!(*vals)
    vals.each { |v|  delete(v) }
    self
  end

  def except(*vals)
    dup.except!(*vals)
  end

  def group_index_by(&blk)
    index = {}
    group_by(&blk).each do |name, group|
      if group.length == 1
        index[group[0]] = name
        next
      end

      idx_digits = Math.log10(group.length).floor + 1
      group.each.with_index do |obj, idx|
        index[obj] = [ name, "%0#{idx_digits}d" % (idx+1) ]
      end
    end
    index
  end

  def deep_reject(&blk)
    dup.deep_reject!(&blk)
  end

  def deep_reject!(&blk)
    idx = 0
    while idx < length do
      val = self[idx]
      val.deep_reject!(&blk)  if val.respond_to?(:deep_reject!)
      if blk.call(idx, val)
        delete_at(idx)
      else
        idx += 1
      end
    end
    self
  end

  def deep_each(&blk)
    idx = 0
    while idx < length do
      val = self[idx]
      if blk.arity == 3
        blk.call(idx, val, self)
        val = self[idx]
      else
        blk.call(idx, val)
      end
      val.deep_each(&blk)  if val.respond_to?(:deep_each)
      idx += 1
    end
    self
  end

  def force_utf8
    map { |el|  el.respond_to?(:force_utf8) ? el.force_utf8 : el }
  end
end

# HASH ############################################################################################

module Hash
  def deep_reject(&blk)
    dup.deep_reject!(&blk)
  end

  def deep_reject!(&blk)
    each do |key, val|
      val.deep_reject!(&blk)  if val.respond_to?(:deep_reject!)
      delete(key)  if blk.call(key, val)
    end
    self
  end

  def deep_each(&blk)
    keys.each do |key|
      val = self[key]
      if blk.arity == 3
        blk.call(key, val, self)
        val = self[key]
      else
        blk.call(key, val)
      end
      val.deep_each(&blk)  if val.respond_to?(:deep_each)
    end
    self
  end

  def deep_map(&blk)
    keys.each do |key|
      val = self[key]
      (blk.arity == 3) ? blk.call(key, val, self) : blk.call(key, val)
      val.deep_each(&blk)  if val.respond_to?(:deep_each)
    end
    self
  end

  def force_utf8
    map do |key, val|
      [
        key.respond_to?(:force_utf8) ? key.force_utf8 : key,
        val.respond_to?(:force_utf8) ? val.force_utf8 : val,
      ]
    end.to_h
  end

  def safe_dig(*path)
    dig(*path)
  rescue TypeError => ex
    return nil  if ex.message.include?('does not have #dig method')
    raise
  end
end

# BOOLEAN #########################################################################################

module String
  def to_bool(default = nil)
    return true  if %w(true  1 yes on  t).include?(self.downcase.strip)
    return false if %w(false 0  no off f).include?(self.downcase.strip)
    default
  end
end
  module Numeric
  def to_bool(_default = nil) !zero? end
end
  module NilClass
  def to_bool(default = nil)  default  end
end
  module TrueClass
  def to_bool(_default = nil)  self  end
end
  module FalseClass
  def to_bool(_default = nil)  self  end
end

# TEMPFILE ########################################################################################

require 'active_support/number_helper/number_to_human_size_converter'
module Tempfile
  def inspect
    "#{path} (#{ActiveSupport::NumberHelper.number_to_human_size(size)})"
  end
end

end

###################################################################################################

CoreExtensions.constants.each do |mod|
  Kernel.const_get(mod).prepend(CoreExtensions.const_get(mod))
end
