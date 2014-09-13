# encoding: UTF-8

module Vines
  class Stream
    # Implements the XMPP protocol for client-to-server (c2s) streams. This
    # serves connected streams using the jabber:client namespace.
    class Client < Stream
      MECHANISMS = %w[PLAIN].freeze

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

      # Return an array of allowed authentication mechanisms advertised as
      # client stream features.
      def authentication_mechanisms
        MECHANISMS
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
        @session.domain = to unless @session.domain
        send_stream_header(from)
        raise StreamErrors::NotAuthorized if domain_change?(to)
        raise StreamErrors::UnsupportedVersion unless node['version'] == '1.0'
        raise StreamErrors::ImproperAddressing unless valid_address?(@session.domain)
        raise StreamErrors::HostUnknown unless config.vhost?(@session.domain)
        raise StreamErrors::InvalidNamespace unless node.namespaces['xmlns'] == NAMESPACES[:client]
        raise StreamErrors::InvalidNamespace unless node.namespaces['xmlns:stream'] == NAMESPACES[:stream]
      end

      private

      # The `to` domain address set on the initial stream header must not change
      # during stream restarts. This prevents a user from authenticating in one
      # domain, then using a stream in a different domain.
      #
      # to - The String domain JID to verify (e.g. 'wonderland.lit').
      #
      # Returns true if the client connection is misbehaving and should be closed.
      def domain_change?(to)
        to != @session.domain
      end

      def send_stream_header(to)
        attrs = {
          'xmlns'        => NAMESPACES[:client],
          'xmlns:stream' => NAMESPACES[:stream],
          'xml:lang'     => 'en',
          'id'           => Kit.uuid,
          'from'         => @session.domain,
          'version'      => '1.0'
        }
        attrs['to'] = to if to
        write "<stream:stream %s>" % attrs.to_a.map{|k,v| "#{k}='#{v}'"}.join(' ')
      end
    end
  end
end
