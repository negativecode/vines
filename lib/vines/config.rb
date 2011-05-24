# encoding: UTF-8

module Vines

  # A Config object is passed to the stream handlers to give them access
  # to server configuration information like virtual host names, storage
  # systems, etc. This class provides the DSL methods used in the
  # config/vines.rb file.
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
        @vhosts.merge! Host.new(name, &block).to_hash
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

    def vhost?(domain)
      @vhosts.key?(domain)
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

    class Host
      def initialize(name, &block)
        @name, @storage, @ldap = name, nil, nil
        instance_eval(&block)
      end

      def storage(name, &block)
        raise "one storage mechanism per host allowed" if @storage
        @storage = Storage.from_name(name, &block)
        @storage.ldap = @ldap
      end

      def ldap(host='localhost', port=636, &block)
        @ldap = Storage::Ldap.new(host, port, &block)
        @storage.ldap = @ldap if @storage
      end

      def to_hash
        raise "storage required for #{@name}" unless @storage
        {@name => @storage}
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

    class ComponentPort < Port
      def initialize(config, host='0.0.0.0', port=5347, &block)
        @components, @stream = {}, Vines::Stream::Component
        super(config, host, port, &block)
      end

      def components(options=nil)
        if options
          @components = options
        else
          @components
        end
      end

      def password(component)
        @components[component]
      end
    end
  end
end
