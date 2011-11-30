# encoding: UTF-8

module Vines
  class Config

    # Provides the DSL methods for the virtual host definitions in the
    # conf/config.rb file. Host instances can be accessed at runtime through
    # the +Config#vhosts+ method.
    class Host
      attr_reader :pubsubs

      def initialize(config, name, &block)
        @config, @name = config, name.downcase
        @storage, @ldap = nil, nil
        @cross_domain_messages = false
        @private_storage = false
        @components, @pubsubs = {}, {}
        validate_domain(@name)
        instance_eval(&block)
        raise "storage required for #{@name}" unless @storage
      end

      def storage(name=nil, &block)
        if name
          raise "one storage mechanism per host allowed" if @storage
          @storage = Storage.from_name(name, &block)
          @storage.ldap = @ldap
        else
          @storage
        end
      end

      def ldap(host='localhost', port=636, &block)
        @ldap = Storage::Ldap.new(host, port, &block)
        @storage.ldap = @ldap if @storage
      end

      def cross_domain_messages(enabled)
        @cross_domain_messages = !!enabled
      end

      def cross_domain_messages?
        @cross_domain_messages
      end

      def components(options=nil)
        return @components unless options

        names = options.keys.map {|domain| "#{domain}.#{@name}".downcase }
        raise "duplicate component domains not allowed" if dupes?(names, @components.keys)
        raise "pubsub domains overlap component domains" if dupes?(names, @pubsubs.keys)

        options.each do |domain, password|
          raise 'component domain required' if (domain || '').to_s.strip.empty?
          raise 'component password required' if (password || '').strip.empty?
          name = "#{domain}.#{@name}".downcase
          raise "components must be one level below their host: #{name}" if domain.to_s.include?('.')
          validate_domain(name)
          @components[name] = password
        end
      end

      def component?(domain)
        !!@components[domain.to_s]
      end

      def password(domain)
        @components[domain.to_s]
      end

      def pubsub(*domains)
        domains.flatten!
        raise 'define at least one pubsub domain' if domains.empty?
        names = domains.map {|domain| "#{domain}.#{@name}".downcase }
        raise "duplicate pubsub domains not allowed" if dupes?(names, @pubsubs.keys)
        raise "pubsub domains overlap component domains" if dupes?(names, @components.keys)
        domains.each do |domain|
          raise 'pubsub domain required' if (domain || '').to_s.strip.empty?
          name = "#{domain}.#{@name}".downcase
          raise "pubsub domains must be one level below their host: #{name}" if domain.to_s.include?('.')
          validate_domain(name)
          @pubsubs[name] = PubSub.new(@config, name)
        end
      end

      def pubsub?(domain)
        @pubsubs.key?(domain.to_s)
      end

      # Unsubscribe this JID from all pubsub topics hosted at this virtual host.
      # This should be called when the user's session ends via logout or
      # disconnect.
      def unsubscribe_pubsub(jid)
        @pubsubs.values.each do |pubsub|
          pubsub.unsubscribe_all(jid)
        end
      end

      def disco_items
        [@components.keys, @pubsubs.keys].flatten.sort
      end

      def private_storage(enabled)
        @private_storage = !!enabled
      end

      def private_storage?
        @private_storage
      end

      private

      # Return true if the arrays contain any duplicate items.
      def dupes?(a, b)
        a.uniq.size != a.size || b.uniq.size != b.size || (a & b).any?
      end

      # Prevent domains in config files that won't form valid JIDs.
      def validate_domain(name)
        jid = JID.new(name)
        raise "incorrect domain: #{name}" if jid.node || jid.resource
      end
    end
  end
end
