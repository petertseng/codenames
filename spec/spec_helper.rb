require 'simplecov'
SimpleCov.start { add_filter '/spec/' }

require 'codenames/game'

def example_game(num_players)
  g = Codenames::Game.new('test')
  num_players.times { |i| g.add_player("p#{i + 1}") }
  g
end
