require 'spec_helper'

require 'codenames/game'

RSpec.describe Codenames::Game do
  let(:example_words) { (0...Codenames::Game::WORDS_PER_GAME).map { |i| "word#{i}" } }

  describe 'setup' do
    let(:game) { example_game(0) }

    it 'can add a player' do
      game.add_player('p1')
      expect(game.size).to be == 1
    end

    it 'can remove a player' do
      game.add_player('p1')
      expect(game.remove_player('p1')).to be true
      expect(game.size).to be == 0
    end

    it 'can replace a player' do
      game.add_player('p1')
      expect(game.replace_player('p1', 'p2')).to be true
      expect(game.size).to be == 1
    end
  end

  describe 'starting a three-player game' do
    shared_examples 'a three-player game with correct team assignments' do
      it 'has equal-sized teams' do
        expect(game.teams.size).to be == Codenames::Game::NUM_TEAMS
        expect(game.teams).to be_all { |x| x.size == 2 }
      end

      it 'has distinct hinters' do
        expect(game.teams).to be_all(&:picked_roles?)
        hinters = game.teams.map(&:hinters)
        expect(hinters[0]).to_not be == hinters[1]
      end

      it 'has one guesser' do
        expect(game.teams).to be_all(&:picked_roles?)
        guessers = game.teams.map(&:guessers)
        expect(guessers[0]).to be == guessers[1]
      end

      it 'is time to give a hint' do
        expect(game.current_phase).to be == :hint
      end

      it 'has no winners yet' do
        expect(game.winning_team_id).to be_nil
        expect(game.winning_players).to be_nil
      end
    end

    shared_examples 'three-player game with one player expressing a preference' do
      let(:preferring_user) { game.users.first }
      before(:each) do
        game.prefer_team(preferring_user, preferred_team)
        game.start(example_words)
      end

      it_should_behave_like 'a three-player game with correct team assignments'

      # We can't make assumptions about which team the player lands on.

      it 'makes the player a hinter' do
        expect(game.role_of(preferring_user)).to be == :hint
      end
    end

    let(:game) { example_game(3) }

    context 'with no team preferences' do
      before(:each) { game.start(example_words) }

      it_should_behave_like 'a three-player game with correct team assignments'
    end

    context 'with one player preferring team 0' do
      let(:preferred_team) { 0 }
      it_should_behave_like 'three-player game with one player expressing a preference'
    end

    context 'with one player preferring team 1' do
      let(:preferred_team) { 1 }
      it_should_behave_like 'three-player game with one player expressing a preference'
    end

    context 'with two players expressing opposite preferences' do
      let(:preferring_users) { game.users[0...Codenames::Game::NUM_TEAMS] }
      before(:each) do
        preferring_users.each_with_index { |user, i| game.prefer_team(user, i) }
        game.start(example_words)
      end

      it_should_behave_like 'a three-player game with correct team assignments'

      # We can't make assumptions about which teams the players land on.

      it 'makes the players hinters' do
        expect(preferring_users).to be_all { |p| game.role_of(p) == :hint }
      end
    end

    context 'with two players expressing same preferences' do
      let(:preferring_users) { game.users[0..1] }
      before(:each) do
        preferring_users.each { |user, i| game.prefer_team(user, 0) }
      end

      it 'does not start the game' do
        success, _ = game.start(example_words)
        expect(success).to be false
      end
    end
  end

  describe 'starting a four-player game' do
    let(:game) { example_game(4) }

    shared_examples 'a four-player game with correct team assignments' do
      it 'has equal-sized teams' do
        expect(game.teams.size).to be == Codenames::Game::NUM_TEAMS
        expect(game.teams).to be_all { |x| x.size == 2 }
      end

      it 'has no roles' do
        expect(game.teams).to_not be_any(&:picked_roles?)
      end

      it 'is time to choose a hinter' do
        expect(game.current_phase).to be == :choose_hinter
      end

      it 'has no winners yet' do
        expect(game.winning_team_id).to be_nil
        expect(game.winning_players).to be_nil
      end
    end

    shared_examples 'four-player game with one player expressing a preference' do
      let(:preferring_user) { game.users.first }
      before(:each) do
        game.prefer_team(preferring_user, preferred_team)
        game.start(example_words)
      end

      it_should_behave_like 'a four-player game with correct team assignments'

      # We can't make assumptions about which team the player lands on.
    end

    context 'with no team preferences' do
      before(:each) { game.start(example_words) }

      it_should_behave_like 'a four-player game with correct team assignments'
    end

    context 'with one player preferring team 0' do
      let(:preferred_team) { 0 }
      it_should_behave_like 'four-player game with one player expressing a preference'
    end

    context 'with one player preferring team 1' do
      let(:preferred_team) { 1 }
      it_should_behave_like 'four-player game with one player expressing a preference'
    end

    context 'with three players expressing same preferences' do
      let(:preferring_users) { game.users[0..2] }
      before(:each) do
        preferring_users.each { |user, i| game.prefer_team(user, 0) }
      end

      it 'shows preferences' do
        expect(game.team_preferences[0].size).to be == 3
      end

      it 'does not start the game' do
        success, _ = game.start(example_words)
        expect(success).to be false
      end
    end
  end

  context 'when choosing hinters' do
    let(:game) { example_game(4) }
    before(:each) { game.start(example_words) }
    let(:hinters) { game.teams.map(&:users).map(&:first) }

    it 'disallows hints' do
      success, _ = game.hint(hinters.first, 'hi', 1)
      expect(success).to be false
    end

    it 'disallows guesses' do
      success, _ = game.guess(hinters.first, 'hi')
      expect(success).to be false
    end

    it 'disallows no-guess' do
      success, _ = game.no_guess(hinters.first)
      expect(success).to be false
    end

    shared_examples 'the first team chose a hinter' do
      it 'gives that team a hinter' do
        expect(game.teams.first.hinters).to_not be_empty
      end

      it 'gives that team a guesser' do
        expect(game.teams.first.guessers).to_not be_empty
      end

      it 'does not touch the other team' do
        expect(game.teams.last).to_not be_picked_roles
      end

      it 'still wants the other team to pick' do
        expect(game.current_phase).to be == :choose_hinter
      end

      it 'disallows another pick from that team' do
        success, _ = game.choose_hinter(hinters.first)
        expect(success).to be false
      end
    end

    context 'when one team chooses specifically' do
      before(:each) { game.choose_hinter(hinters.first) }

      it_should_behave_like 'the first team chose a hinter'
    end

    context 'when one team chooses randomly' do
      before(:each) { game.choose_hinter(hinters.first, random: true) }

      it_should_behave_like 'the first team chose a hinter'
    end

    context 'when both teams choose' do
      before(:each) { hinters.each { |hinter| game.choose_hinter(hinter) } }

      it 'gives both teams hinters' do
        expect(game.teams).to_not be_any { |team| team.hinters.empty? }
      end

      it 'gives both teams guessers' do
        expect(game.teams).to_not be_any { |team| team.guessers.empty? }
      end

      it 'is time to give a hint' do
        expect(game.current_phase).to be == :hint
      end
    end
  end

  context 'when giving hints' do
    let(:game) { example_game(4) }
    let(:hinters) { game.teams.map(&:users).map(&:first) }
    let(:hinter) { hinters.first }
    let(:guessers) { game.teams.map(&:users).map(&:last) }
    before(:each) {
      game.start(example_words)
      hinters.each { |hinter| game.choose_hinter(hinter) }
    }

    it 'has a current team' do
      expect(game.current_team.id).to be == game.current_team_id
    end

    it 'disallows choosing hinters' do
      success, _ = game.choose_hinter(hinter)
      expect(success).to be false
    end

    it 'disallows guesses' do
      success, _ = game.guess(hinter, 'hi')
      expect(success).to be false
    end

    it 'disallows no-guess' do
      success, _ = game.no_guess(hinter)
      expect(success).to be false
    end

    it 'disallows the other hinter from giving a hint' do
      success, _ = game.hint(hinters.last, 'hi', 1)
      expect(success).to be false
    end

    it 'disallows the guesser from giving a hint' do
      success, _ = game.hint(guessers.first, 'hi', 1)
      expect(success).to be false
    end

    context 'with good hint' do
      before(:each) { game.hint(hinter, 'hi', 1) }

      it 'remembers the hint word' do
        expect(game.current_hint_word).to be == 'hi'
      end

      it 'remembers the hint number' do
        expect(game.current_hint_number).to be == 1
      end

      it 'is time to guess' do
        expect(game.current_phase).to be == :guess
      end
    end

    describe 'number validation' do
      it 'accepts unlimited' do
        success, _ = game.hint(hinter, 'hi', 'unlimited')
        expect(success).to be true
        expect(game.guesses_remaining).to be == Float::INFINITY
      end

      it 'accepts infinity' do
        success, _ = game.hint(hinter, 'hi', Float::INFINITY)
        expect(success).to be true
        expect(game.guesses_remaining).to be == Float::INFINITY
      end

      it 'accepts a number' do
        success, _ = game.hint(hinter, 'hi', 1)
        expect(success).to be true
        expect(game.guesses_remaining).to be == 2
      end

      it 'accepts a string' do
        success, _ = game.hint(hinter, 'hi', '1')
        expect(success).to be true
        expect(game.guesses_remaining).to be == 2
      end

      it 'accepts zero' do
        success, _ = game.hint(hinter, 'hi', 0)
        expect(success).to be true
        expect(game.guesses_remaining).to be == Float::INFINITY
      end

      it 'rejects a bogus string' do
        success, _ = game.hint(hinter, 'hi', '1cheese')
        expect(success).to be false
      end

      it 'rejects a negative number' do
        success, _ = game.hint(hinter, 'hi', -1)
        expect(success).to be false
      end

      it 'rejects a too-large number' do
        success, _ = game.hint(hinter, 'hi', Codenames::Game::TEAM_WORDS[0] + 1)
        expect(success).to be false
      end
    end
  end

  context 'when guessing' do
    let(:game) { example_game(4) }
    let(:hinters) { game.teams.map(&:users).map(&:first) }
    let(:guessers) { game.teams.map(&:users).map(&:last) }
    let(:guesser) { guessers.first }
    before(:each) {
      game.start(example_words)
      hinters.each { |hinter| game.choose_hinter(hinter) }
      game.hint(hinters.first, 'hi', 1)
    }

    it 'has a current team' do
      expect(game.current_team.id).to be == game.current_team_id
    end

    it 'disallows choosing hinters' do
      success, _ = game.choose_hinter(hinters.first)
      expect(success).to be false
    end

    it 'disallows hints' do
      success, _ = game.hint(hinters.first, 'hi', 1)
      expect(success).to be false
    end

    it 'disallows no-guess before having made a guess' do
      success, _ = game.no_guess(guesser)
      expect(success).to be false
    end

    it 'disallows the other guesser from guessing' do
      success, _ = game.guess(guessers.last, example_words.first)
      expect(success).to be false
    end

    it 'disallows the hinter from guessing' do
      success, _ = game.guess(hinters.first, example_words.first)
      expect(success).to be false
    end

    context 'when making a correct guess' do
      let(:word_to_guess) { game.hinter_words[0].first }
      before(:each) { game.guess(guesser, word_to_guess) }

      it 'is reflected in public info' do
        expect(game.public_words[:guessed][0]).to_not be_empty
      end

      it 'continues the turn' do
        expect(game.current_team_id).to be == 0
      end

      it 'expends a guess' do
        expect(game.guesses_remaining).to be == 1
      end

      it 'allows no-guess' do
        success, _ = game.no_guess(guesser)
        expect(success).to be true
      end

      it 'ends the turn on a no-guess' do
        game.no_guess(guesser)
        expect(game.current_team_id).to_not be == 0
      end

      it 'ends the turn when guesses run out' do
        game.guess(guesser, game.hinter_words[0].last)
        expect(game.current_team_id).to_not be == 0
      end
    end

    context 'when guessing a word of the other team' do
      let(:word_to_guess) { game.hinter_words[1].first }
      before(:each) { game.guess(guesser, word_to_guess) }

      it 'is reflected in public info' do
        expect(game.public_words[:guessed][1]).to_not be_empty
      end

      it 'ends the turn' do
        expect(game.current_team_id).to_not be == 0
      end
    end

    context 'when guessing a neutral word' do
      let(:word_to_guess) { game.hinter_words[:neutral].first }
      before(:each) { game.guess(guesser, word_to_guess) }

      it 'is reflected in public info' do
        expect(game.public_words[:guessed][:neutral]).to_not be_empty
      end

      it 'ends the turn' do
        expect(game.current_team_id).to_not be == 0
      end
    end

    context 'when guessing the assassin' do
      let(:word_to_guess) { game.hinter_words[:assassin].first }
      before(:each) { game.guess(guesser, word_to_guess) }

      it 'makes the other team the winners' do
        expect(game.winning_team_id).to be == 1
        expect(game.winning_players).to_not be_empty
      end
    end
  end

  describe 'winning the game by finding all words' do
    let(:game) { example_game(4) }
    let(:hinters) { game.teams.map(&:users).map(&:first) }
    let(:guessers) { game.teams.map(&:users).map(&:last) }
    let(:guesser) { guessers.first }
    before(:each) {
      game.start(example_words)
      hinters.each { |hinter| game.choose_hinter(hinter) }
      game.hint(hinters.first, 'hi', 0)
      game.hinter_words[0].drop(1).each { |word| game.guess(guesser, word) }
    }

    it 'ends the game in victory' do
      expect(game.winning_team_id).to be_nil
      game.hinter_words[0].each { |word| game.guess(guesser, word) }
      expect(game.winning_team_id).to be == 0
      expect(game.winning_players).to_not be_empty
    end
  end
end
