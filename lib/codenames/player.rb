module Codenames; class Player
  attr_accessor :user
  attr_reader :team, :role
  attr_accessor :team_preference

  def initialize(user)
    @user = user
    @team_preference = nil
    @role = nil
    @team = nil
  end

  def to_s
    @user.respond_to?(:name) ? @user.name : @user
  end

  def role=(new_role)
    raise "#{self} already has role #{@role}" if @role
    @role = new_role
  end

  def team=(new_team)
    raise "#{self} already has team #{@team}" if @team
    @team = new_team
  end

  def on_team?(team)
    @team == team || @team == :both
  end
end; end