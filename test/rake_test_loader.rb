#!/usr/bin/env ruby

# Use the latest MiniTest gem instead of the buggy
# version included with Ruby 1.9.2.
gem 'minitest'

# Load the test files from the command line.

ARGV.each { |f| load f unless f =~ /^-/  }
