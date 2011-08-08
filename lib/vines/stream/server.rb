# encoding: UTF-8

module Vines
  class Stream

    # Implements the XMPP protocol for server-to-server (s2s) streams. This
    # serves connected streams using the jabber:server namespace. This handles
    # both accepting incoming s2s streams and initiating outbound s2s streams
    # to other servers.
    class Server < Stream

      # Starts the connection to the remote server. When the stream is
      # connected and ready to send stanzas it will yield to the callback
      # block. The callback is run on the EventMachine reactor thread. The
      # yielded stream will be nil if the remote connection failed. We need to
      # use a background thread to avoid blocking the server on DNS SRV
      # lookups.
      def self.start(config, to, from, &callback)
        op = proc do
          Resolv::DNS.open do |dns|
            dns.getresources("_xmpp-server._tcp.#{to}", Resolv::DNS::Resource::IN::SRV)
          end.sort! {|a,b| a.priority == b.priority ? b.weight <=> a.weight : a.priority <=> b.priority }
        end
        cb = proc do |srv|
          if srv.empty?
            srv << {:target => to, :port => 5269}
            class << srv.first
              def method_missing(name); self[name]; end
            end
          end
          Server.connect(config, to, from, srv, callback)
        end
        EM.defer(proc { op.call rescue [] }, cb)
      end

      def self.connect(config, to, from, srv, callback)
        if srv.empty?
          callback.call(nil)
        else
          begin
            rr = srv.shift
            opts = {:to => to, :from => from, :srv => srv, :callback => callback}
            EM.connect(rr.target.to_s, rr.port, Server, config, opts)
          rescue Exception => e
            connect(config, to, from, srv, callback)
          end
        end
      end

      attr_reader :config, :domain
      attr_accessor :remote_domain

      def initialize(config, options={})
        @config = config
        @remote_domain = options[:to]
        @domain = options[:from]
        @srv = options[:srv]
        @callback = options[:callback]
        @outbound = @remote_domain && @domain
        start = @outbound ? Outbound::Start.new(self) : Start.new(self)
        advance(start)
      end

      def post_init
        super
        send_stream_header if @outbound
      end

      def max_stanza_size
        @config[:server].max_stanza_size
      end

      def ssl_handshake_completed
        close_connection unless cert_domain_matches?(@remote_domain)
      end

      def stream_type
        :server
      end

      def unbind
        super
        if @outbound && !ready?
          Server.connect(@config, @remote_domain, @domain, @srv, @callback)
        end
      end

      def vhost?(domain)
        @config.vhost?(domain)
      end

      def notify_connected
        if @callback
          @callback.call(self)
          @callback = nil
        end
      end

      def ready?
        state.class == Server::Ready
      end

      def start(node)
        if @outbound then send_stream_header; return end
        @domain, @remote_domain = %w[to from].map {|a| node[a] }
        send_stream_header
        raise StreamErrors::UnsupportedVersion unless node['version'] == '1.0'
        raise StreamErrors::ImproperAddressing unless valid_address?(@domain) && valid_address?(@remote_domain)
        raise StreamErrors::HostUnknown unless @config.vhost?(@domain)
        raise StreamErrors::NotAuthorized unless @config.s2s?(@remote_domain)
        raise StreamErrors::InvalidNamespace unless node.namespaces['xmlns'] == NAMESPACES[:server]
        raise StreamErrors::InvalidNamespace unless node.namespaces['xmlns:stream'] == NAMESPACES[:stream]
      end

      private

      def send_stream_header
        attrs = {
          'xmlns' => NAMESPACES[:server],
          'xmlns:stream' => NAMESPACES[:stream],
          'xml:lang' => 'en',
          'id' => Kit.uuid,
          'from' => @domain,
          'to' => @remote_domain,
          'version' => '1.0'
        }
        write "<stream:stream %s>" % attrs.to_a.map{|k,v| "#{k}='#{v}'"}.join(' ')
      end
    end
  end
end
