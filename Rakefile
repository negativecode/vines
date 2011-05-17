require 'rake'
require 'rake/clean'
require 'rake/gempackagetask'
require 'rake/testtask'
require_relative 'lib/vines/version'

spec = Gem::Specification.new do |s| 
  s.name    = "vines"
  s.version = Vines::VERSION
  s.date    = Time.now.strftime("%Y-%m-%d")

  s.summary     = "Vines is an XMPP chat server that's easy to install and run."
  s.description = "Vines is an XMPP chat server that supports thousands of
simultaneous connections by using EventMachine for asynchronous IO. User data
is stored in a SQL database, CouchDB, Redis, the file system, or a custom storage
implementation that you provide. LDAP authentication can be used so user names
and passwords aren't stored in the chat database. SSL encryption is mandatory on
all client and server connections."

  s.authors      = ["David Graham", "Chris Johnson"]
  s.email        = %w[david@negativecode.com chris@negativecode.com]
  s.homepage     = "http://www.getvines.com"

  s.files        = FileList['[A-Z]*', '{bin,lib,conf}/**/*']
  s.test_files   = FileList["test/**/*"]
  s.executables  = %w[vines]
  s.require_path = "lib"

  s.add_dependency "activerecord", "~> 3.0"
  s.add_dependency "bcrypt-ruby", "~> 2.1"
  s.add_dependency 'em-http-request', '>= 1.0.0.beta.3'
  s.add_dependency "em-redis", "~> 0.3"
  s.add_dependency "eventmachine", ">= 1.0.0.beta.3"
  s.add_dependency "http_parser.rb", "~> 0.5"
  s.add_dependency "net-ldap", "~> 0.2"
  s.add_dependency "nokogiri", "~> 1.4"

  s.add_development_dependency "minitest"
  s.add_development_dependency "rake"
  s.add_development_dependency "sqlite3"

  s.required_ruby_version = '>= 1.9.2'
end

Rake::GemPackageTask.new(spec) do |pkg| 
  pkg.need_tar = true
end

module Rake
  class TestTask
    # use our custom test loader
    def rake_loader
      'test/rake_test_loader.rb'
    end
  end
end

Rake::TestTask.new(:test) do |test|
  test.libs << 'test'
  test.libs << 'test/storage'
  test.pattern = 'test/**/*_test.rb'
  test.warning = false
end

task :default => [:clobber, :test, :gem]
