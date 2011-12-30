# encoding: UTF-8

module Vines
  class Cluster
    # Subscribes to the redis nodes:all broadcast channel to listen for
    # heartbeats from other cluster members. Also subscribes to a channel
    # exclusively for this particular node, listening for stanzas routed to us
    # from other nodes.
    class Subscriber
      include Vines::Log

      ALL, FROM, HEARTBEAT, OFFLINE, ONLINE, STANZA, TIME, TO, TYPE, USER =
        %w[cluster:nodes:all from heartbeat offline online stanza time to type user].map {|s| s.freeze }

      def initialize(cluster)
        @cluster = cluster
        @channel = "cluster:nodes:#{@cluster.id}"
        @messages = EM::Queue.new
        process_messages
      end

      # Create a new redis connection and subscribe to the nodes:all broadcast
      # channel as well as the channel for this cluster node. Redis connections
      # in subscribe mode cannot be used for other key/value operations.
      def subscribe
        conn = @cluster.connect
        conn.subscribe(ALL)
        conn.subscribe(@channel)
        conn.on(:message) do |channel, message|
          @messages.push([channel, message])
        end
      end

      private

      # Recursively process incoming messages from the queue, guaranteeing they
      # are processed in the order they are received.
      def process_messages
        @messages.pop do |channel, message|
          Fiber.new do
            on_message(channel, message)
            process_messages
          end.resume
        end
      end

      # Process messages as they arrive on the pubsub channels to which we're
      # subscribed.
      def on_message(channel, message)
        doc = JSON.parse(message)
        case channel
        when ALL      then to_all(doc)
        when @channel then to_node(doc)
        end
      rescue Exception => e
        log.error("Cluster subscription message failed: #{e}")
      end

      # Process a message sent to the nodes:all broadcast channel. In the case
      # of node heartbeats, we update the last time we heard from this node so
      # we can cleanup its session if it goes offline.
      def to_all(message)
        case message[TYPE]
        when ONLINE, HEARTBEAT
          @cluster.poke(message[FROM], message[TIME])
        when OFFLINE
          @cluster.delete_sessions(message[FROM])
        end
      end

      # Process a message published to this node's channel. Messages sent to
      # this channel are stanzas that need to be routed to connections attached
      # to this node.
      def to_node(message)
        case message[TYPE]
        when STANZA then route_stanza(message)
        when USER   then update_user(message)
        end
      end

      # Send the stanza, from a remote cluster node, to locally connected
      # streams for the destination user.
      def route_stanza(message)
        node = Nokogiri::XML(message[STANZA]).root rescue nil
        return unless node
        log.debug { "Received cluster stanza: %s -> %s\n%s\n" % [message[FROM], @cluster.id, node] }
        if node[TO]
          @cluster.connected_resources(node[TO]).each do |recipient|
            recipient.write(node)
          end
        else
          log.warn("Cluster stanza missing address:\n#{node}")
        end
      end

      # Update the roster information, that's cached in locally connected
      # streams, for this user.
      def update_user(message)
        jid = JID.new(message['jid']).bare
        if user = @cluster.storage(jid.domain).find_user(jid)
          @cluster.connected_resources(jid).each do |stream|
            stream.user.update_from(user)
          end
        end
      end
    end
  end
end
