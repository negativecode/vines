# encoding: UTF-8

module Vines
  class Config

    # Provides the DSL methods for the virtual host definitions in the
    # conf/config.rb file. Host instances can be accessed at runtime through
    # the +Config#vhosts+ method.
    class Host
      def initialize(name, &block)
        @name, @storage, @ldap = name.downcase, nil, nil
        @cross_domain_messages = false
        @private_storage = false
        @components = {}
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
        dupes = names.uniq.size != names.size || (@components.keys & names).any?
        raise "duplicate component domains not allowed" if dupes

        options.each do |domain, password|
          raise 'component domain required' if (domain || '').to_s.strip.empty?
          raise 'component password required' if (password || '').strip.empty?
          @components["#{domain}.#{@name}".downcase] = password
        end
      end

      def component?(domain)
        !!@components[domain]
      end

      def password(domain)
        @components[domain]
      end

      def private_storage(enabled)
        @private_storage = !!enabled
      end

      def private_storage?
        @private_storage
      end
    end
  end
end
