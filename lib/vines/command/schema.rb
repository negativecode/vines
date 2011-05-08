# encoding: UTF-8

module Vines
  module Command
    class Schema
      def run(opts)
        raise 'vines schema <domain>' unless opts[:args].size == 1
        require opts[:config]
        domain = opts[:args].first
        unless storage = Config.instance.vhosts[domain]
          raise "#{domain} virtual host not found in conf/config.rb"
        end
        unless storage.respond_to?(:create_schema)
          raise "SQL storage not configured for #{domain} virtual host"
        end
        begin
          storage.create_schema
        rescue Exception => e
          raise "Schema creation failed: #{e.message}"
        end
      end
    end
  end
end