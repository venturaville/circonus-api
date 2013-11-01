Gem::Specification.new do |s|
  s.name = "circonus"
  s.version = "1.0.15"
  s.license = 'MIT'
  s.email = "david-vv@nicklay.com"
  s.homepage = "https://github.com/venturaville/circonus-api"
  s.authors = ["David Nicklay"]
  s.summary = "Circonus API wrapper and CLI"
  s.files = Dir['lib/**/*.rb'] + Dir['bin/*'] + Dir['examples/*.rb']
  s.description = "Wrapper and CLI for Circonus API"
  s.bindir = "bin"
  s.executables = %w{ circonus-cli circonus-data-cli }
  %w{ rest-client ripl yajl-ruby }.each do |d|
    s.add_dependency d
  end
end
