require 'rake'
require 'rake/clean'
require 'rake/gempackagetask'
require 'rake/testtask'
require 'nokogiri'
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

  s.files        = FileList['[A-Z]*', '{bin,lib,conf,web}/**/*']
  s.test_files   = FileList["test/**/*"]
  s.executables  = %w[vines]
  s.require_path = "lib"

  s.add_dependency "activerecord", "~> 3.0"
  s.add_dependency "bcrypt-ruby", "~> 2.1"
  s.add_dependency 'em-http-request', '>= 1.0.0.beta.3'
  s.add_dependency "em-redis", "~> 0.3"
  s.add_dependency "eventmachine", "~> 0.12"
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

# Find lib and chat js includes and return them as two arrays.
def scripts(doc)
  lib, chat = [], []
  doc.css('script').each do |node|
    file = node['src'].split('/').last()
    if node['src'].start_with?('/lib')
      lib << file
    elsif node['src'].start_with?('/chat')
      chat << file
    end
  end
  [lib, chat]
end

# Replace script tags with combined and minimized files.
def rewrite_js(doc)
  doc.css('script').each {|node| node.remove }
  doc.css('head').each do |node|
    %w[/lib/javascripts/base.js /chat/javascripts/app.js].each do |src|
      script = doc.create_element('script',
        'type' => 'text/javascript',
        'src' => src)
      node.add_child(script)
      node.add_child(doc.create_text_node("\n"))
    end
  end
end

task :compile do
  index = 'web/chat/index.html'
  doc = Nokogiri::HTML(File.read(index))
  lib, chat = scripts(doc)

  rewrite_js(doc)
  # save index.html before rewriting
  FileUtils.cp(index, '/tmp/index.html')
  File.open(index, 'w') {|f| f.write(doc.to_xml(:indent => 2)) }

  lib = lib.map {|f| "web/lib/javascripts/#{f}"}.join(' ')
  chat = chat.map {|f| "web/chat/javascripts/#{f}"}.join(' ')

  sh %{coffee -c -b -o web/chat/javascripts web/chat/coffeescripts/*.coffee}
  sh %{cat #{chat} | uglifyjs -nc > web/chat/javascripts/app.js}

  sh %{coffee -c -b -o web/lib/javascripts web/lib/coffeescripts/*.coffee}
  sh %{cat #{lib} | uglifyjs -nc > web/lib/javascripts/base.js}
end

task :cleanup do
  # move index.html back into place after gem packaging
  FileUtils.cp('/tmp/index.html', 'web/chat/index.html')
  File.delete('/tmp/index.html')
end

task :default => [:clobber, :test, :compile, :gem, :cleanup]
