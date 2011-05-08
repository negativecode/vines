# encoding: UTF-8

module Vines
  class Stream

    # Implements the XMPP protocol for client-to-server (c2s) streams. This
    # serves connected streams using the jabber:client namespace.
    class Client < Stream
      attr_reader :config, :domain
      attr_accessor :last_broadcast_presence

      def initialize(config)
        @config = config
        @domain = nil
        @requested_roster = false
        @available = false
        @unbound = false
        @last_broadcast_presence = nil
        @state = Start.new(self)
      end

      def ssl_handshake_completed
        if get_peer_cert
          close_connection unless cert_domain_matches?(@domain)
        end
      end

      def max_stanza_size
        @config[:client].max_stanza_size
      end

      def max_resources_per_account
        @config[:client].max_resources_per_account
      end

      def unbind
        @unbound = true
        @available = false
        if authenticated?
          doc = Nokogiri::XML::Document.new
          el = doc.create_element('presence', 'type' => 'unavailable')
          Stanza::Presence::Unavailable.new(el, self).outbound_broadcast_presence
        end
        super
      end

      # Returns true if this client has properly authenticated with
      # the server.
      def authenticated?
        !@user.nil?
      end

      # A connected resource has authenticated and bound a resource
      # identifier.
      def connected?
        !@unbound && authenticated? && !@user.jid.bare?
      end

      # An available resource has sent initial presence and can
      # receive presence subscription requests.
      def available?
        @available && connected?
      end

      # An interested resource has requested its roster and can
      # receive roster pushes.
      def interested?
        @requested_roster && connected?
      end

      def available!
        @available = true
      end

      def requested_roster!
        @requested_roster = true
      end

      # Returns streams for available resources to which this user
      # has successfully subscribed.
      def available_subscribed_to_resources
        subscribed = @user.subscribed_to_contacts.map {|c| c.jid }
        router.available_resources(subscribed)
      end

      # Returns streams for available resources that are subscribed
      # to this user's presence updates.
      def available_subscribers
        subscribed = @user.subscribed_from_contacts.map {|c| c.jid }
        router.available_resources(subscribed)
      end

      # Returns contacts hosted at remote servers that are subscribed
      # to this user's presence updates.
      def remote_subscribers(to=nil)
        jid = (to.nil? || to.empty?) ? nil : JID.new(to).bare
        @user.subscribed_from_contacts.reject do |c|
          router.local_jid?(c.jid) || (jid && c.jid.bare != jid)
        end
      end

      def ready?
        @state.class == Client::Ready
      end

      def start(node)
        @domain, from = %w[to from].map {|a| node[a] }
        send_stream_header(from)
        raise StreamErrors::UnsupportedVersion unless node['version'] == '1.0'
        raise StreamErrors::HostUnknown unless @config.vhost?(@domain)
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
          'from' => @domain,
          'version' => '1.0'
        }
        attrs['to'] = to if to
        write "<stream:stream %s>" % attrs.to_a.map{|k,v| "#{k}='#{v}'"}.join(' ')
      end
    end
  end
end
