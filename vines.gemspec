require './lib/vines/version'

Gem::Specification.new do |s|
  s.name    = 'vines'
  s.version = Vines::VERSION

  s.summary     = "Vines is an XMPP chat server that's easy to install and run."
  s.description = "Vines is an XMPP chat server that supports thousands of
simultaneous connections by using EventMachine for asynchronous IO. User data
is stored in a SQL database, CouchDB, MongoDB, Redis, the file system, or a
custom storage implementation that you provide. LDAP authentication can be used
so user names and passwords aren't stored in the chat database. SSL encryption
is mandatory on all client and server connections."

  s.authors      = ["David Graham"]
  s.email        = %w[david@negativecode.com]
  s.homepage     = "http://www.getvines.org"
  s.license      = 'MIT'

  s.files        = Dir['[A-Z]*', 'vines.gemspec', '{bin,lib,conf,web}/**/*'] - ['Gemfile.lock']
  s.test_files   = Dir['test/**/*']
  s.executables  = %w[vines]
  s.require_path = 'lib'

  s.add_dependency "activerecord", "~> 3.2.1"
  s.add_dependency "bcrypt-ruby", "~> 3.0.1"
  s.add_dependency "em-http-request", "~> 1.0.1"
  s.add_dependency "em-hiredis", "~> 0.1.0"
  s.add_dependency "eventmachine", "1.0.0.beta.4"
  s.add_dependency "http_parser.rb", "~> 0.5.3"
  s.add_dependency "mongo", "~> 1.5.2"
  s.add_dependency "bson_ext", "~> 1.5.2"
  s.add_dependency "net-ldap", "~> 0.2.2"
  s.add_dependency "nokogiri", "~> 1.4.7"

  s.add_development_dependency "minitest", "~> 2.11.2"
  s.add_development_dependency "coffee-script", "~> 2.2.0"
  s.add_development_dependency "coffee-script-source", "~> 1.2.0"
  s.add_development_dependency "uglifier", "~> 1.2.3"
  s.add_development_dependency "rake"
  s.add_development_dependency "sqlite3"

  s.required_ruby_version = '>= 1.9.2'
end
