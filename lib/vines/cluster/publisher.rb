# encoding: UTF-8

module Vines
  class Cluster
    # Broadcast messages to other cluster nodes via redis pubsub channels. All
    # members subscribe to a channel for heartbeats, online, and offline
    # messages from other nodes. This allows new nodes to be added to the
    # cluster dynamically, without configuring all other nodes.
    class Publisher
      include Vines::Log

      ALL, STANZA, USER = %w[cluster:nodes:all stanza user].map {|s| s.freeze }

      def initialize(cluster)
        @cluster = cluster
      end

      # Publish a :heartbeat, :online, or :offline message to the nodes:all
      # broadcast channel.
      def broadcast(type)
        redis.publish(ALL, {
          from: @cluster.id,
          type: type,
          time: Time.now.to_i
        }.to_json)
      end

      # Send the stanza to the node hosting the user's session. The stanza is
      # published to the channel to which the remote node is listening for
      # messages.
      def route(stanza, node)
        log.debug { "Sent cluster stanza: %s -> %s\n%s\n" % [@cluster.id, node, stanza] }
        redis.publish("cluster:nodes:#{node}", {
          from: @cluster.id,
          type: STANZA,
          stanza: stanza.to_s
        }.to_json)
      end

      # Notify the remote node that the user's roster has changed and it should
      # reload the user from storage.
      def update_user(jid, node)
        redis.publish("cluster:nodes:#{node}", {
          from: @cluster.id,
          type: USER,
          jid: jid.to_s
        }.to_json)
      end

      def redis
        @cluster.connection
      end
    end
  end
end
