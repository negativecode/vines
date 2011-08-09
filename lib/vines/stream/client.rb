# encoding: UTF-8

module Vines
  class Stream

    # Implements the XMPP protocol for client-to-server (c2s) streams. This
    # serves connected streams using the jabber:client namespace.
    class Client < Stream
      def initialize(config)
        super
        @session = Client::Session.new(self)
      end

      # Delegate behavior to the session that's storing our stream state.
      def method_missing(name, *args)
        @session.send(name, *args)
      end

      %w[advance domain state user user=].each do |name|
        define_method name do |*args|
          @session.send(name, *args)
        end
      end

      %w[max_stanza_size max_resources_per_account].each do |name|
        define_method name do |*args|
          config[:client].send(name, *args)
        end
      end

      def ssl_handshake_completed
        if get_peer_cert
          close_connection unless cert_domain_matches?(@session.domain)
        end
      end

      def unbind
        @session.unbind!(self)
        super
      end

      def start(node)
        to, from = %w[to from].map {|a| node[a] }
        @session.domain = to
        send_stream_header(from)
        raise StreamErrors::UnsupportedVersion unless node['version'] == '1.0'
        raise StreamErrors::ImproperAddressing unless valid_address?(@session.domain)
        raise StreamErrors::HostUnknown unless config.vhost?(@session.domain)
        raise StreamErrors::InvalidNamespace unless node.namespaces['xmlns'] == NAMESPACES[:client]
        raise StreamErrors::InvalidNamespace unless node.namespaces['xmlns:stream'] == NAMESPACES[:stream]
      end

      private

      def send_stream_header(to)
        attrs = {
          'xmlns' => NAMESPACES[:client],
          'xmlns:stream' => NAMESPACES[:stream],
          'xml:lang' => 'en',
          'id' => Kit.uuid,
          'from' => @session.domain,
          'version' => '1.0'
        }
        attrs['to'] = to if to
        write "<stream:stream %s>" % attrs.to_a.map{|k,v| "#{k}='#{v}'"}.join(' ')
      end
    end
  end
end
