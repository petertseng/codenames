module Codenames; class Hint
  Guess = Struct.new(:word, :role)

  attr_reader :team, :word, :number, :guesses_remaining
  def initialize(team, word, number)
    @team = team
    @word = word.freeze
    @number = number
    @guesses_remaining = number == 0 ? Float::INFINITY : number + 1
    @guesses = []
  end

  def guessed_this_turn?
    !@guesses.empty?
  end

  def guesses
    @guesses.dup
  end

  def guess(guessed_word, role)
    raise "guesses for #{self} exhausted: #{@guesses}" if @guesses_remaining <= 0
    @guesses << Guess.new(guessed_word.downcase.freeze, role).freeze
    @guesses_remaining -= 1
  end

  def to_s
    "#{@word} #{@number == Float::INFINITY ? 'unlimited' : @number}"
  end
end; end
