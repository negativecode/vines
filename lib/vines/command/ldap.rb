# encoding: UTF-8

module Vines
  module Command
    class Ldap
      def run(opts)
        raise 'vines ldap <domain>' unless opts[:args].size == 1
        require opts[:config]
        domain = opts[:args].first
        unless storage = Config.instance.vhost(domain).storage rescue nil
          raise "#{domain} virtual host not found in conf/config.rb"
        end
        unless storage.ldap?
          raise "LDAP connector not configured for #{domain} virtual host"
        end
        $stdout.write('JID: ')
        jid = $stdin.gets.chomp
        jid = [jid, domain].join('@') unless jid.include?('@')
        $stdout.write('Password: ')
        `stty -echo`
        password = $stdin.gets.chomp
        `stty echo`
        puts

        begin
          user = storage.ldap.authenticate(jid, password)
        rescue Exception => e
          raise "LDAP connection failed: #{e.message}"
        end

        filter = storage.ldap.filter(jid)
        raise "User not found with filter:\n  #{filter}" unless user
        name = user.name.empty? ? '<name missing>' : user.name
        puts "Found user #{name} with filter:\n  #{filter}"
      end
    end
  end
end
