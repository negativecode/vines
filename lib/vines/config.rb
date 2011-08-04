# encoding: UTF-8

module Vines

  # A Config object is passed to the stream handlers to give them access
  # to server configuration information like virtual host names, storage
  # systems, etc. This class provides the DSL methods used in the
  # conf/config.rb file.
  class Config
    LOG_LEVELS = %w[debug info warn error fatal].freeze

    attr_reader :vhosts

    @@instance = nil
    def self.configure(&block)
      @@instance = self.new(&block)
    end

    def self.instance
      @@instance
    end

    def initialize(&block)
      @vhosts, @ports = {}, {}
      instance_eval(&block)
      raise "must define at least one virtual host" if @vhosts.empty?
    end

    def host(*names, &block)
      names = names.flatten.map {|name| name.downcase }
      dupes = names.uniq.size != names.size || (@vhosts.keys & names).any?
      raise "one host definition per domain allowed" if dupes
      names.each do |name|
        @vhosts[name] = Host.new(name, &block)
      end
    end

    %w[client server http component].each do |name|
      define_method(name) do |*args, &block|
        port = Vines::Config.const_get("#{name.capitalize}Port")
        raise "one #{name} port definition allowed" if @ports[name.to_sym]
        @ports[name.to_sym] = port.new(self, *args) do
          instance_eval(&block) if block
        end
      end
    end

    def log(level)
      const = Logger.const_get(level.to_s.upcase) rescue nil
      unless LOG_LEVELS.include?(level.to_s) && const
        raise "log level must be one of: #{LOG_LEVELS.join(', ')}"
      end
      Class.new.extend(Vines::Log).log.level = const
    end

    def ports
      @ports.values
    end

    # Return true if the domain is virtual hosted by this server.
    def vhost?(domain)
      @vhosts.key?(domain)
    end

    # Return true if all JID's belong to components hosted by this server.
    def component?(*jids)
      !jids.flatten.index do |jid|
        !component_password(JID.new(jid).domain)
      end
    end

    # Return the password for the component or nil if it's not hosted here.
    def component_password(domain)
      host = @vhosts.values.find {|host| host.component?(domain) }
      host.password(domain) if host
    end

    # Return true if all of the JID's are hosted by this server.
    def local_jid?(*jids)
      !jids.flatten.index do |jid|
        !vhost?(JID.new(jid).domain)
      end
    end

    # Returns true if server-to-server connections are allowed with the
    # given domain.
    def s2s?(domain)
      @ports[:server] && @ports[:server].hosts.include?(domain)
    end

    # Retrieve the Port subclass with this name:
    # [:client, :server, :http, :component]
    def [](name)
      @ports[name] or raise ArgumentError.new("no port named #{name}")
    end

    # Return true if the two JID's are allowed to send messages to each other.
    # Both domains must have enabled cross_domain_messages in their config files.
    def allowed?(to, from)
      to, from = JID.new(to), JID.new(from)
      return false                      if to.empty? || from.empty?
      return true                       if to.domain == from.domain # same domain always allowed
      return cross_domain?(to, from)    if local_jid?(to, from)     # both virtual hosted here
      return check_components(to, from) if component?(to, from)     # component to component
      return check_component(to, from)  if component?(to)           # to component
      return check_component(from, to)  if component?(from)         # from component
      return cross_domain?(to)          if local_jid?(to)           # from is remote
      return cross_domain?(from)        if local_jid?(from)         # to is remote
      return false
    end

    private

    def check_components(to, from)
      comp1, comp2 = strip_domain(to), strip_domain(from)
      (comp1 == comp2) || cross_domain?(comp1, comp2)
    end

    def check_component(component_jid, jid)
      comp = strip_domain(component_jid)
      return true if comp.domain == jid.domain
      local_jid?(jid) ? cross_domain?(comp, jid) : cross_domain?(comp)
    end

    # Return the JID's domain with the first subdomain stripped off. For example,
    # alice@tea.wonderland.lit returns wonderland.lit.
    def strip_domain(jid)
      domain = jid.domain.split('.').drop(1).join('.')
      JID.new(domain)
    end

    # Return true if all JID's are allowed to exchange cross domain messages.
    def cross_domain?(*jids)
      !jids.flatten.index do |jid|
        !@vhosts[jid.domain].cross_domain_messages?
      end
    end
  end
end

module Vines
  class Config
    class Host
      def initialize(name, &block)
        @name, @storage, @ldap = name, nil, nil
        @cross_domain_messages = false
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
        if options
          options.each do |domain, password|
            raise 'component domain required' if (domain || '').to_s.strip.empty?
            raise 'component password required' if (password || '').strip.empty?
            @components["#{domain}.#{@name}"] = password
          end
        else
          @components
        end
      end

      def component?(domain)
        !!@components[domain]
      end

      def password(domain)
        @components[domain]
      end
    end

    class Port
      include Vines::Log

      attr_reader :config, :stream

      %w[host port].each do |name|
        define_method(name) do
          @settings[name.to_sym]
        end
      end

      def initialize(config, host, port, &block)
        @config, @settings = config, {}
        instance_eval(&block) if block
        defaults = {:host => host, :port => port,
          :max_resources_per_account => 5, :max_stanza_size => 128 * 1024}
        @settings = defaults.merge(@settings)
      end

      def max_stanza_size(max=nil)
        if max
          # rfc 6120 section 13.12
          @settings[:max_stanza_size] = [10000, max].max
        else
          @settings[:max_stanza_size]
        end
      end

      def start
        type = stream.name.split('::').last.downcase
        log.info("Accepting #{type} connections on #{host}:#{port}")
        EventMachine::start_server(host, port, stream, config)
      end
    end

    class ClientPort < Port
      def initialize(config, host='0.0.0.0', port=5222, &block)
        @stream = Vines::Stream::Client
        super(config, host, port, &block)
      end

      def max_resources_per_account(max=nil)
        if max
          @settings[:max_resources_per_account] = max
        else
          @settings[:max_resources_per_account]
        end
      end

      def private_storage(enabled)
        @settings[:private_storage] = !!enabled
      end

      def private_storage?
        @settings[:private_storage]
      end
    end

    class ServerPort < Port
      def initialize(config, host='0.0.0.0', port=5269, &block)
        @hosts, @stream = [], Vines::Stream::Server
        super(config, host, port, &block)
      end

      def hosts(*hosts)
        if hosts.any?
          @hosts << hosts
          @hosts.flatten!
        else
          @hosts
        end
      end
    end

    class HttpPort < Port
      def initialize(config, host='0.0.0.0', port=5280, &block)
        @stream = Vines::Stream::Http
        super(config, host, port, &block)
        defaults = {:root => File.expand_path('web'), :bind => '/xmpp'}
        @settings = defaults.merge(@settings)
      end

      def max_resources_per_account(max=nil)
        if max
          @settings[:max_resources_per_account] = max
        else
          @settings[:max_resources_per_account]
        end
      end

      def private_storage(enabled)
        @settings[:private_storage] = !!enabled
      end

      def private_storage?
        @settings[:private_storage]
      end

      def root(dir=nil)
        if dir
          @settings[:root] = File.expand_path(dir)
        else
          @settings[:root]
        end
      end

      def bind(url=nil)
        if url
          @settings[:bind] = url
        else
          @settings[:bind]
        end
      end
    end

    class ComponentPort < Port
      def initialize(config, host='0.0.0.0', port=5347, &block)
        @stream = Vines::Stream::Component
        super(config, host, port, &block)
      end
    end
  end
end
