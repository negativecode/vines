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

        attr_accessor :domain, :user
        attr_reader   :id, :last_broadcast_presence, :state

        def initialize(stream)
          @id = Kit.uuid
          @config = stream.config
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
          save_to_cluster
        end

        # An available resource has sent initial presence and can
        # receive presence subscription requests.
        def available?
          @available && connected?
        end

        def bind!(resource)
          @user.jid.resource = resource
          save_to_cluster
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

        def last_broadcast_presence=(node)
          @last_broadcast_presence = node
          save_to_cluster
        end

        def ready?
          @state.class == Client::Ready
        end

        def requested_roster!
          @requested_roster = true
          save_to_cluster
        end

        def stream_type
          :client
        end

        # Called by the stream when its disconnected from the client. The stream
        # passes itself to this method in case multiple streams are accessing this
        # session.
        def unbind!(stream)
          delete_from_cluster
          @unbound = true
          @available = false
          broadcast_unavailable
        end

        # Returns streams for available resources to which this user
        # has successfully subscribed.
        def available_subscribed_to_resources
          subscribed = @user.subscribed_to_contacts.map {|c| c.jid }
          router.available_resources(subscribed, @user.jid)
        end

        # Returns streams for available resources that are subscribed
        # to this user's presence updates.
        def available_subscribers
          subscribed = @user.subscribed_from_contacts.map {|c| c.jid }
          router.available_resources(subscribed, @user.jid)
        end

        # Returns contacts hosted at remote servers to which this user has
        # successfully subscribed.
        def remote_subscribed_to_contacts
          @user.subscribed_to_contacts.reject do |c|
            @config.local_jid?(c.jid)
          end
        end

        # Returns contacts hosted at remote servers that are subscribed
        # to this user's presence updates.
        def remote_subscribers(to=nil)
          jid = (to.nil? || to.empty?) ? nil : JID.new(to).bare
          @user.subscribed_from_contacts.reject do |c|
            @config.local_jid?(c.jid) || (jid && c.jid.bare != jid)
          end
        end

        private

        def broadcast_unavailable
          return unless authenticated?
          Fiber.new do
            broadcast(unavailable, available_subscribers)
            broadcast(unavailable, router.available_resources(@user.jid, @user.jid))
            remote_subscribers.each do |contact|
              node = el.clone
              node['to'] = contact.jid.bare.to_s
              router.route(node) rescue nil # ignore RemoteServerNotFound
            end
          end.resume
        end

        def unavailable
          doc = Nokogiri::XML::Document.new
          doc.create_element('presence',
            'from' => @user.jid.to_s,
            'type' => 'unavailable')
        end

        def broadcast(stanza, recipients)
          recipients.each do |recipient|
            stanza['to'] = recipient.user.jid.to_s
            recipient.write(stanza)
          end
        end

        def router
          @config.router
        end

        def save_to_cluster
          if @config.cluster?
            @config.cluster.save_session(@user.jid, to_hash)
          end
        end

        def delete_from_cluster
          if connected? && @config.cluster?
            @config.cluster.delete_session(@user.jid)
          end
        end

        def to_hash
          presence = @last_broadcast_presence ? @last_broadcast_presence.to_s : nil
          {available: @available, interested: @requested_roster, presence: presence.to_s}
        end
      end
    end
  end
end
