# codenames

This is a Ruby implementation of game logic for "Codenames" by Vlaada Chvátil

https://boardgamegeek.com/boardgame/178900

[![Build Status](https://travis-ci.org/petertseng/codenames.svg?branch=master)](https://travis-ci.org/petertseng/codenames)

This document uses the generic name "Hinter" for the role giving the hints and "Guesser" for the role trying to guess words (these are "Spymaster" and "Field Agent" respectively in the published version of the game).

# Basic Usage

To create a game, call `Codenames::Game.new(channel_name: String, players: Hash[User => Integer?], words: Array[String]?)`.
The keys of the `players` hash are the players who will be in the game.
`User` can be any type that is convenient, such as a string or any other form of user identifier.
The corresponding value for each player can be 0 or 1 to indicate a preference for one of two teams, or nil to indicate no preference.
Players who do not specify a preference are placed on teams to balance the team sizes as much as possible, or randomly placed if the teams are already balanced.
Which team goes first is randomly decided.

The list of words may be set using one of two ways: `Codenames::Game.possible_words = words`, or as the optional second argument to `Game#initialize`.
If both ways are used, the latter takes precedence.
The list of words needs to respond to `#size` (to verify that there are at least as many as required in one Codenames game) and `#sample` to randomly select the words for a single game.
For example, an `Array` will do.

Teams may be queried with `Game#teams -> Array[Team]` and `Team#users`.

Functions performing game actions generally return a two-element array where the first element is a boolean to indicate whether the action was successful.
The second element may vary as follows:
If the action failed, it is always the case that an `Error` is returned, and a sensible string describing what went wrong can be obtained with `Error#to_s -> String`.
If the action succeeded, some functions return extra data regarding the result of the action, while some other functions simply return nil as the extra data, as they have no extra information to impart.

If playing a three-player game, which players are Hinters will have already been decided, as there is only one possible Hinter for each team (the Guesser plays for both teams).
Otherwise, the Hinter for each team must be chosen.
One player from each team must become Hinter with `Game#choose_hinter(User) -> [Boolean(success), Either[Boolean(both_teams_chose), Error]]` or use random choice with `Game#choose_hinter(User, random: true)`.

The Hinters submit hints with `Game#hint(User, String(word), Either[String(num), Integer]) -> [Boolean(success), Error?]`.
The Guessers submit guesses with `Game#guess(User, String(word)) -> [Boolean(success), Either[GuessResult, Error]]`.
The Guessers may pass with `Game#no_guess(User) -> [Boolean(success), Error?]` once at least one guess has been submitted.

The game is won when `Game#winning_team_id -> Integer?` or `Game#winning_players -> Array[User]?` return non-nil values.
If the game is not won, both functions return nil.
It is always the case that either both return non-nil or both return nil.
This is because it would not be sensible to have half-won games.

# Tests

The automated tests are run with `rspec`.
Running automatically generates a coverage report (made with [simplecov](https://github.com/colszowka/simplecov)).

If a bug is found in the game logic, write a test that fails with the broken logic, then fix the game logic.

If a new feature is added, a test should be added.
Coverage should remain high.
As of this writing, the only uncovered lines are `Error#to_s` (13 lines), `Player#to_s` (1 line), `Game::distrbute` for > 2 teams (3 lines) and `Game#guess` for an invalid word role (1 line).
