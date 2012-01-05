# encoding: UTF-8

module Vines
  module Command
    class Bcrypt
      def run(opts)
        raise 'vines bcrypt <clear text>' unless opts[:args].size == 1
        require 'bcrypt' unless defined?(BCrypt)
        puts BCrypt::Password.create(opts[:args].first)
      end
    end
  end
end
