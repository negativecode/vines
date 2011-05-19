# encoding: UTF-8

module Vines
  class Stream
    class Client
      # A Session tracks the state of a client stream over its lifetime from
      # negotiation to processing stanzas to shutdown. By disconnecting the
      # stream's state from the stream, we can allow multiple TCP connections
      # to access one logical session (e.g. HTTP streams).
      class Session
        include Comparable

        attr_accessor :domain, :last_broadcast_presence, :user
        attr_reader   :id, :state

        def initialize(stream)
          @id = Kit.uuid
          @state = Client::Start.new(stream)
          @available = false
          @domain = nil
          @last_broadcast_presence = nil
          @requested_roster = false
          @unbound = false
          @user = nil
        end

        def <=>(session)
          session.is_a?(Session) ? self.id <=> session.id : nil
        end

        alias :eql? :==

        def hash
          @id.hash
        end

        def advance(state)
          @state = state
        end

        # Returns true if this client has properly authenticated with
        # the server.
        def authenticated?
          !@user.nil?
        end

        def available!
          @available = true
        end

        # An available resource has sent initial presence and can
        # receive presence subscription requests.
        def available?
          @available && connected?
        end

        # A connected resource has authenticated and bound a resource
        # identifier.
        def connected?
          !@unbound && authenticated? && !@user.jid.bare?
        end

        # An interested resource has requested its roster and can
        # receive roster pushes.
        def interested?
          @requested_roster && connected?
        end

        def ready?
          @state.class == Client::Ready
        end

        def requested_roster!
          @requested_roster = true
        end

        def stream_type
          :client
        end

        # Called by the stream when its disconnected from the client. The stream
        # passes itself to this method in case multiple streams are accessing this
        # session.
        def unbind!(stream)
          @unbound = true
          @available = false
          broadcast_unavailable
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

        private

        def broadcast_unavailable
          return unless authenticated?

          doc = Nokogiri::XML::Document.new
          el = doc.create_element('presence',
            'from' => @user.jid.to_s,
            'type' => 'unavailable')

          broadcast(el, available_subscribers)
          broadcast(el, router.available_resources(@user.jid))

          remote_subscribers.each do |contact|
            node = el.clone
            node['to'] = contact.jid.bare.to_s
            router.route(node) rescue nil # ignore RemoteServerNotFound
          end
        end

        def broadcast(stanza, recipients)
          recipients.each do |recipient|
            stanza['to'] = recipient.user.jid.to_s
            recipient.write(stanza)
          end
        end

        def router
          Router.instance
        end
      end
    end
  end
end
