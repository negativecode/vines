# encoding: UTF-8

require 'rake'
require 'rake/clean'
require 'rake/testtask'
require 'rubygems/package_task'
require 'coffee-script'
require 'uglifier'

ignore = File.read('web/lib/javascripts/.gitignore')
  .split("\n").map {|f| "web/lib/javascripts/#{f}" }

CLOBBER.include('pkg', 'web/chat/javascripts', *ignore)

desc 'Build distributable packages'
task :build => :assets do
  system "gem build vines.gemspec"
end

Rake::TestTask.new(:test) do |test|
  test.libs << 'test'
  test.libs << 'test/storage'
  test.pattern = 'test/**/*_test.rb'
  test.warning = false
end

desc 'Compile and minimize web assets'
task :assets do
  # combine and compile library coffeescripts
  File.open('web/lib/javascripts/base.js', 'w') do |basejs|
    assets = %w[layout button contact filter session transfer router navbar notification login logout]
    coffee = assets.inject('') do |sum, name|
      sum + File.read("web/lib/coffeescripts/#{name}.coffee")
    end
    js = %w[jquery jquery.cookie raphael icons strophe].inject('') do |sum, name|
      sum + File.read("web/lib/javascripts/#{name}.js")
    end
    compiled = js + CoffeeScript.compile(coffee)
    compressed = Uglifier.compile(compiled)
    basejs.write(compressed)
  end

  # combine and compile chat application's coffeescripts
  Dir.mkdir('web/chat/javascripts') unless File.exists?('web/chat/javascripts')
  File.open('web/chat/javascripts/app.js', 'w') do |appjs|
    coffee = %w[chat init].inject('') do |sum, name|
      sum + File.read("web/chat/coffeescripts/#{name}.coffee")
    end
    compiled = CoffeeScript.compile(coffee)
    compressed = Uglifier.compile(compiled)
    appjs.write(compressed)
  end
end

task :default => [:clobber, :test, :build]
