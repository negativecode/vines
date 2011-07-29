# encoding: UTF-8

module Vines
  class Storage

    # Authenticates usernames and passwords against an LDAP directory. This can
    # provide authentication logic for the other, full-featured Storage
    # implementations while they store and retrieve the rest of the user
    # information.
    class Ldap
      @@required = [:host, :port]
      %w[tls dn password basedn object_class user_attr name_attr groupdn].each do |name|
        @@required << name.to_sym unless name == 'groupdn'
        define_method name do |*args|
          @config[name.to_sym] = args.first
        end
      end

      def initialize(host='localhost', port=636, &block)
        @config = {:host => host, :port => port}
        instance_eval(&block)
        @@required.each {|key| raise "Must provide #{key}" if @config[key].nil? }
      end

      # Validates a username and password by binding to the LDAP instance with
      # those credentials. If the bind succeeds, the user's attributes are
      # retrieved.
      def authenticate(username, password)
        return if [username, password].any? {|arg| (arg || '').strip.empty? }

        ldap = connect(@config[:dn], @config[:password])
        entries = ldap.search(
          :attributes => [@config[:name_attr], 'mail'],
          :filter => filter(username))
        return unless entries && entries.size == 1

        user = if connect(entries.first.dn, password).bind
          name = entries.first[@config[:name_attr]].first
          User.new(:jid => username, :name => name.to_s, :roster => [])
        end
        user
      end

      # Return an LDAP search filter for a user optionally belonging to the
      # group defined by the groupdn config attribute.
      def filter(username)
        clas = Net::LDAP::Filter.eq('objectClass', @config[:object_class])
        uid = Net::LDAP::Filter.eq(@config[:user_attr], username)
        filter = clas & uid
        if group = @config[:groupdn]
          memberOf = Net::LDAP::Filter.eq('memberOf', group)
          isMemberOf = Net::LDAP::Filter.eq('isMemberOf', group)
          filter = filter & (memberOf | isMemberOf)
        end
        filter
      end

      private

      def connect(dn, password)
        options = [:host, :port, :base].zip(
          @config.values_at(:host, :port, :basedn))
        Net::LDAP.new(Hash[options]).tap do |ldap|
          ldap.encryption(:simple_tls) if @config[:tls]
          ldap.auth(dn, password)
        end
      end
    end
  end
end
