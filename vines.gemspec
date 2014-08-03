require './lib/vines/version'

Gem::Specification.new do |s|
  s.name         = 'vines'
  s.version      = Vines::VERSION
  s.summary      = %q[Vines is an XMPP chat server that's easy to install and run.]
  s.description  = %q[Vines is an XMPP chat server that supports thousands of simultaneous connections, using EventMachine and Nokogiri.]

  s.authors      = ['David Graham']
  s.email        = %w[david@negativecode.com]
  s.homepage     = 'http://www.getvines.org'
  s.license      = 'MIT'

  s.files        = Dir['[A-Z]*', 'vines.gemspec', '{bin,lib,conf,web}/**/*'] - ['Gemfile.lock']
  s.test_files   = Dir['test/**/*']
  s.executables  = %w[vines]
  s.require_path = 'lib'

  s.add_dependency 'bcrypt', '~> 3.1'
  s.add_dependency 'em-hiredis', '~> 0.1.1'
  s.add_dependency 'eventmachine', '~> 1.0'
  s.add_dependency 'http_parser.rb', '~> 0.6'
  s.add_dependency 'net-ldap', '~> 0.6'
  s.add_dependency 'nokogiri', '~> 1.6'

  s.add_development_dependency 'minitest', '~> 5.3'
  s.add_development_dependency 'rake', '~> 10.3'

  s.required_ruby_version = '>= 1.9.3'
end
