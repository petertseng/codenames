# Team helps external users query team information.
#
# This is safe to return to external users from Game methods.
#
# Well, assuming they don't use instance_variable_get to get at @players,
# but if they were going to do that then they can probably do whatever.
#
# Since this is safe to return, it can't return Players, only Users.
module Codenames; class Team
  attr_reader :id

  def initialize(id, players)
    @id = id
    @players = players
  end

  def size
    @players.size
  end

  def users
    @players.map(&:user)
  end

  def picked_roles?
    @players.all?(&:role)
  end

  def with_role(role)
    @players.select { |p| p.role == role }.map(&:user)
  end

  def hinters
    with_role(:hint)
  end

  def guessers
    with_role(:guess)
  end
end; end
