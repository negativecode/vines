# encoding: UTF-8

module Vines
  class Config
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

      def start
        super
        config.cluster.start if config.cluster?
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

      def vroute(id=nil)
        if id
          id = id.to_s.strip
          @settings[:vroute] = id.empty? ? nil : id
        else
          @settings[:vroute]
        end
      end

      def start
        super
        if config.cluster? && vroute.nil?
          log.warn("vroute sticky session cookie not set")
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
