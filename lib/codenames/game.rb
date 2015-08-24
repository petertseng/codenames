require_relative 'error'
require_relative 'player'
require_relative 'team'
require_relative 'word'

module Codenames; class Game
  GAME_NAME = 'Codenames'.freeze
  MIN_PLAYERS = 3
  MAX_PLAYERS = 100

  WORDS_PER_GAME = 25
  HINTERS_PER_TEAM = 1
  ASSASSIN_WORDS = 1
  TEAM_WORDS = [9, 8].freeze
  NUM_TEAMS = TEAM_WORDS.size
  TOTAL_TEAM_WORDS = TEAM_WORDS.inject(0, :+)
  NEUTRAL_WORDS = WORDS_PER_GAME - TOTAL_TEAM_WORDS - ASSASSIN_WORDS

  attr_reader :id, :channel_name, :started, :start_time, :turn_number
  attr_reader :teams
  attr_reader :current_team, :current_phase, :current_hint, :guesses_remaining
  attr_reader :guessed_this_turn
  attr_reader :winning_team

  alias :started? :started
  alias :guessed_this_turn? :guessed_this_turn

  class << self
    attr_accessor :games_created
    attr_accessor :possible_words
  end

  @games_created = 0
  @possible_words = {}

  def initialize(channel_name)
    self.class.games_created += 1
    @id = self.class.games_created
    @channel_name = channel_name
    @players = []

    @teams = [].freeze

    @started = false
    @start_time = nil

    @words = {}
    @scores = Array.new(NUM_TEAMS, 0)

    @turn_number = 0
    @current_team = 0
    @current_phase = :setup
    @current_hint = nil
    @guesses_remaining = nil
    @guessed_this_turn = false

    @winning_team = nil
  end

  #----------------------------------------------
  # Required methods for player management
  #----------------------------------------------

  def size
    @players.size
  end

  def users
    @players.map(&:user)
  end

  def has_player?(user)
    @players.any? { |p| p.user == user }
  end

  def add_player(user)
    raise "Cannot add #{user} to #{@channel_name}: game in progress" if @started
    return false if has_player?(user)
    new_player = Player.new(user)
    @players << new_player
    true
  end

  def remove_player(user)
    raise "Cannot remove #{user} from #{@channel_name}: game in progress" if @started
    player = find_player(user)
    return false unless player
    @players.delete(player)
    true
  end

  def replace_player(replaced, replacing)
    player = find_player(replaced)
    return false unless player
    player.user = replacing
    true
  end

  #----------------------------------------------
  # Assign players to teams
  #----------------------------------------------

  def self.assignments(players_to_assign)
    by_team = players_to_assign.group_by(&:team_preference)
    NUM_TEAMS.times { |i| by_team[i] ||= [] }
    distribute(by_team[nil], among: (0...NUM_TEAMS).map { |i| by_team[i] })

    NUM_TEAMS.times { |i|
      # Couldn't make teams!
      return [false, Error.new(:no_guesser, i)] if by_team[i].size <= HINTERS_PER_TEAM
    }

    teams = (0...NUM_TEAMS).map { |i| by_team[i] }.shuffle
    [true, teams]
  end

  def self.distribute(undecided, among:)
    undecided.shuffle!

    if among.size == 2
      a, b = among
      # if one is smaller than the other, balance them out as close as possible
      if a.size < b.size
        diff = b.size - a.size
        a.concat(undecided.pop(diff))
      elsif a.size > b.size
        diff = a.size - b.size
        b.concat(undecided.pop(diff))
      end

      # if there are any left over, split them evenly
      a.concat(undecided.pop(undecided.size / 2))
      b.concat(undecided)
      undecided.clear
      return
    end

    # Too lazy to optimize the > 2 team case.
    # We'll just do it the slow way.
    until undecided.empty?
      smallest_team = among.min_by(&:size)
      smallest_team << undecided.pop
    end
  end

  def self.three_player_assignments(players_to_assign)
    by_team = players_to_assign.group_by(&:team_preference)

    NUM_TEAMS.times { |i|
      # Sorry it doesn't really make sense if two players pick the same team in 3p.
      return [false, Error.new(:no_guesser, i)] if by_team[i] && by_team[i].size >= 2
    }

    if by_team[nil].size == 3
      # If everyone picked no team, randomly pick it.
      players_to_assign.shuffle!
      return [true, {
        hint: players_to_assign[0..1],
        guess: players_to_assign[2],
      }]
    elsif by_team[nil].size == 2
      # Two players have no team and the other player picked a team.
      # One of the two players will need to be the other team.
      by_team[nil].shuffle!
      if by_team[0] && by_team[0].size == 1
        by_team[1] = [by_team[nil].pop]
      else
        by_team[0] = [by_team[nil].pop]
      end
      return [true, {
        hint: [by_team[0].first, by_team[1].first].shuffle,
        guess: by_team[nil].first,
      }]
    end

    # It's not possible for by_team[nil].size to be == 0
    # because some team would have had >= 2 and we would have errored.
    # So by_team[nil].size == 1.
    # In addition, the other two are not on the same team.
    # So this must be the case where one person is on every team.
    [true, {
      hint: [by_team[0].first, by_team[1].first].shuffle,
      guess: by_team[nil].first,
    }]
  end

  #----------------------------------------------
  # Game state getters
  #----------------------------------------------

  def role_of(user)
    player = find_player(user)
    player && player.role
  end

  def team_preferences
    @players.group_by(&:team_preference).map { |team, players|
      [team, players.map(&:user)]
    }.to_h
  end

  # This is information everyone gets to see:
  # The list of unguessed words, and full info on guessed words.
  def public_words
    guessed, unguessed = @words.values.partition(&:revealed)
    {
      unguessed: unguessed.map(&:word).sort,
      guessed: guessed.group_by(&:role).map { |k, vs| [k, vs.map(&:word)] }.to_h,
    }
  end

  # Only hinters see identities of unguessed words.
  def hinter_words(exclude_revealed: true)
    to_show = exclude_revealed ? @words.values.reject(&:revealed) : @words.values
    grouped = to_show.group_by(&:role)
    grouped.map { |role, words| [role, words.map(&:word)] }.to_h
  end

  def other_team
    1 - @current_team
  end

  def winning_players
    return nil unless @winning_team
    # Eh, I guess I'll consider the guesser in a 3p to always win?
    @players.select { |p| p.on_team?(@winning_team) }.map(&:user)
  end

  #----------------------------------------------
  # Game state changers
  #----------------------------------------------

  def prefer_team(user, team)
    player = find_player(user)
    return error(:not_in_game) unless player
    return error(:wrong_time, :setup) if @started
    return error(:invalid_team) unless team.nil? || (0 <= team && team < NUM_TEAMS)
    player.team_preference = team
    [true, nil]
  end

  def start(possible_words = nil)
    return error(:wrong_time, :setup) if @started
    possible_words ||= self.class.possible_words

    return error(:not_enough_words, WORDS_PER_GAME) if !possible_words || possible_words.size < WORDS_PER_GAME

    if @players.size == 3
      success, assignment_or_err = self.class.three_player_assignments(@players)
      return [success, assignment_or_err] unless success
      assignment = assignment_or_err
      assignment[:hint].each_with_index { |player, i|
        player.role = :hint
        player.team = i
      }
      assignment[:guess].role = :guess
      assignment[:guess].team = :both
      # They can skip the hinter selection.
      @turn_number = 1
      @current_phase = :hint
    else
      success, assignment_or_err = self.class.assignments(@players)
      return [success, assignment_or_err] unless success
      assignment_or_err.each_with_index { |players, i|
        players.each { |p| p.team = i }
      }
      @current_phase = :choose_hinter
    end

    @teams = (0...NUM_TEAMS).map { |i| Team.new(i, @players.select { |p| p.on_team?(i) }) }.freeze

    # Assign words.
    words = possible_words.sample(WORDS_PER_GAME).map { |word| word.downcase.strip }
    words.pop(ASSASSIN_WORDS).each { |word| @words[word] = Word.new(word, :assassin) }
    TEAM_WORDS.each_with_index { |n, i|
      words.pop(n).each { |word| @words[word] = Word.new(word, i) }
    }
    words.each { |word| @words[word] = Word.new(word, :neutral) }

    @started = true
    [true, nil]
  end
  alias :start_game :start

  # Returns [false, error_sym] or [true, Boolean(everyone_chose?)]
  def choose_hinter(user, random: false)
    player = find_player(user)
    return error(:not_in_game) unless player
    return error(:already_chose_hinter) if @teams[player.team].picked_roles?
    return error(:wrong_time, :choose_hinter) unless @current_phase == :choose_hinter

    if random
      random_player = @players.select { |p| p.on_team?(player.team) }.sample
      player_becomes_hinter(random_player)
    else
      player_becomes_hinter(player)
    end

    [true, @teams.all?(&:picked_roles?)]
  end

  GuessResult = Struct.new(:role, :correct, :turn_ends, :winner)

  def guess(user, word)
    result = check_role(user, :guess)
    return result unless result.first

    word_info = @words[word.downcase.strip]
    return error(:word_not_found) unless word_info
    return error(:word_already_guessed) if word_info.revealed?

    word_info.reveal!
    @guessed_this_turn = true

    case word_info.role
    when :assassin
      @winning_team = other_team
      @current_phase = :game_over
      return [true, GuessResult.new(:assassin, false, true, other_team)]
    when :neutral
      stop_guess_phase
      return [true, GuessResult.new(:neutral, false, true, nil)]
    when Integer
      @scores[word_info.role] += 1
      someone_won = check_victory
      @guesses_remaining -= 1
      turn_ends = word_info.role != @current_team || @guesses_remaining <= 0
      stop_guess_phase if turn_ends && !someone_won

      return [true, GuessResult.new(
        word_info.role,
        word_info.role == @current_team,
        turn_ends,
        someone_won ? @winning_team : nil,
      )]
    else; raise "Game #{@channel_name} word #{@word.word} has bad role #{word_info.role}"
    end
  end

  def no_guess(user)
    result = check_role(user, :guess)
    return result unless result.first
    return error(:must_guess) unless @guessed_this_turn
    stop_guess_phase
    [true, nil]
  end

  def hint(user, word, num)
    result = check_role(user, :hint)
    return result unless result.first

    words_remaining = TEAM_WORDS[@current_team] - @scores[@current_team]

    return error(:bad_number, words_remaining) if num.nil?

    if num.to_s.downcase == 'unlimited' || num == Float::INFINITY
      @guesses_remaining = Float::INFINITY
    elsif num.is_a?(String) && num.to_i.to_s != num
      return error(:bad_number, words_remaining)
    elsif num.to_i == 0
      @guesses_remaining = Float::INFINITY
    elsif (1..words_remaining).include?(num.to_i)
      @guesses_remaining = num.to_i + 1
    else
      return error(:bad_number, words_remaining)
    end

    @current_phase = :guess
    @current_hint = word.freeze
    @guessed_this_turn = false

    [true, nil]
  end

  private

  def find_player(user)
    @players.find { |p| p.user == user }
  end

  def error(sym, arg = nil)
    [false, Error.new(sym, arg)]
  end

  def check_role(user, phase)
    player = find_player(user)
    return error(:not_in_game) unless player
    return error(:wrong_team) unless player.on_team?(@current_team)
    return error(:wrong_role, phase) unless player.role == phase
    return error(:wrong_time, phase) unless @current_phase == phase

    [true, nil]
  end

  def player_becomes_hinter(player)
    player.role = :hint
    @players.select { |p| p.on_team?(player.team) && p != player }.each { |p| p.role = :guess }
    if @teams.all?(&:picked_roles?)
      @current_phase = :hint
      @turn_number = 1
    end
  end

  def check_victory
    TEAM_WORDS.each_with_index { |goal, i|
      if @scores[i] >= goal
        @current_phase = :game_over
        @winning_team = i
        return true
      end
    }
    false
  end

  def stop_guess_phase
    raise "Game #{@channel_name} not in guess phase" unless @current_phase == :guess
    @turn_number += 1
    @current_team = other_team
    @current_phase = :hint
    @current_hint = nil
    @guesses_remaining = nil
  end
end; end
