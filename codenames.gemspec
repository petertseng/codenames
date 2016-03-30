Gem::Specification.new do |s|
  s.name          = 'codenames'
  s.version       = '1.0.0'
  s.summary       = 'Codenames'
  s.description   = 'Backend for managing a Codenames game'
  s.authors       = ['Peter Tseng']
  s.email         = 'pht24@cornell.edu'
  s.homepage      = 'https://github.com/petertseng/codenames'

  s.files         = Dir['LICENSE', 'README.md', 'lib/**/*']
  s.test_files    = Dir['spec/**/*']
  s.require_paths = ['lib']

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'simplecov'
end
