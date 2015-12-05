require 'simplecov'
SimpleCov.start { add_filter '/spec/' }

require 'codenames/game'

RSpec.configure { |c|
  c.warnings = true
  c.disable_monkey_patching!
}
