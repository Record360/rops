require_relative 'lib/version'

Gem::Specification.new do |s|
  s.name        = 'rops'
  s.version     = Record360::Operations::VERSION
  s.summary     = "Record360 Operations tool"
  s.description = "A tool to checkout, build, and deploy projects using Git, Docker, and Kubernetes"
  s.authors     = ["Steve Sloan"]
  s.email       = 'steve@record360.com'
  s.files       =  Dir['lib/**/*.rb'] + Dir['bin/*'] + Dir['[A-Z]*']
  s.executables = %w(rops)
  s.homepage    = 'https://github.com/Record360/rops'
  s.license     = 'MIT'

  s.add_runtime_dependency 'dry-cli', '~> 0.7.0'
  s.add_runtime_dependency 'activesupport', '~> 7.0.3'
  s.add_runtime_dependency 'git', '>= 1.9.1', '< 1.14.0'
  s.add_runtime_dependency 'ptools', '~> 1.4.2'
  s.add_runtime_dependency 'hashdiff', '~> 1.0.1'
  s.add_runtime_dependency 'net-ssh', '~> 6.1.0'
  s.add_runtime_dependency 'liquid', '~> 5.4.0'
end
