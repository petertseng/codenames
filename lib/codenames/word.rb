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
