module Codenames; class Error < StandardError
  def initialize(sym, arg)
    @sym = sym
    @arg = arg
  end

  def to_s
    case @sym
    when :no_guesser; "both teams need at least one #{Text::ROLES[:guess]}"
    when :not_enough_words; "not enough words given, we need #{@arg}"

    when :not_in_game; 'you are not in the game'

    when :invalid_team; "team #{@arg} is invalid"

    when :already_chose_hinter; "your team already has a #{Text::ROLES[:hint]}"

    when :wrong_time; "you must wait for the #{@arg} phase to do that"
    when :wrong_team; 'you are not on that team'
    when :wrong_role; "you are not a #{Text::ROLES[@arg]}"

    when :word_not_found; 'that word is not in this game'
    when :word_already_guessed; 'that word has already been guessed'

    when :must_guess; 'you must make at least one guess'

    when :bad_number; "that is an invalid number: need unlimited or number between 0 and #{@arg}"
    end
  end
end; end
