# Word help keep track of word => role/revealed mappings.
#
# This should be used internally only, never returned from any Game method.
# This is because I don't want people messing Word#reveal!
module Codenames; class Word
  attr_reader :word, :revealed, :role
  alias :revealed? :revealed

  def initialize(word, role)
    @word = word.freeze
    @revealed = false
    @role = role
  end

  def reveal!
    raise "#{@word} already revealed" if @revealed
    @revealed = true
  end
end; end
