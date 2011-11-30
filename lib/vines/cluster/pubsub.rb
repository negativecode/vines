# encoding: UTF-8

module Vines
  class Cluster
    # Manages the pubsub topic list and subscribers stored in redis. When a
    # message is published to a topic, the receiving cluster node broadcasts
    # the message to all subscribers at all other cluster nodes.
    class PubSub
      def initialize(cluster)
        @cluster = cluster
      end

      # Create a pubsub topic (a.k.a. node), in the given domain, to which
      # messages may be published. The domain argument will be one of the
      # configured pubsub subdomains in conf/config.rb (e.g. games.wonderland.lit,
      # topics.wonderland.lit, etc).
      def add_node(domain, node)
        redis.sadd("pubsub:#{domain}:nodes", node)
      end

      # Remove a pubsub topic so messages may no longer be broadcast to it.
      def delete_node(domain, node)
        redis.smembers("pubsub:#{domain}:subscribers_#{node}") do |subscribers|
          redis.multi
          subscribers.each do |jid|
            redis.srem("pubsub:#{domain}:subscriptions_#{jid}", node)
          end
          redis.del("pubsub:#{domain}:subscribers_#{node}")
          redis.srem("pubsub:#{domain}:nodes", node)
          redis.exec
        end
      end

      # Subscribe the JID to the pubsub topic so it will receive any messages
      # published to it.
      def subscribe(domain, node, jid)
        jid = JID.new(jid)
        redis.multi
        redis.sadd("pubsub:#{domain}:subscribers_#{node}", jid.to_s)
        redis.sadd("pubsub:#{domain}:subscriptions_#{jid}", node)
        redis.exec
      end

      # Unsubscribe the JID from the pubsub topic, deregistering its interest
      # in receiving any messages published to it.
      def unsubscribe(domain, node, jid)
        jid = JID.new(jid)
        redis.multi
        redis.srem("pubsub:#{domain}:subscribers_#{node}", jid.to_s)
        redis.srem("pubsub:#{domain}:subscriptions_#{jid}", node)
        redis.exec
        redis.scard("pubsub:#{domain}:subscribers_#{node}") do |count|
          delete_node(domain, node) if count == 0
        end
      end

      # Unsubscribe the JID from all pubsub topics. This is useful when the
      # JID's session ends by logout or disconnect.
      def unsubscribe_all(domain, jid)
        jid = JID.new(jid)
        redis.smembers("pubsub:#{domain}:subscriptions_#{jid}") do |nodes|
          nodes.each do |node|
            unsubscribe(domain, node, jid)
          end
        end
      end

      # Return true if the pubsub topic exists and messages may be published to it.
      def node?(domain, node)
        @cluster.query(:sismember, "pubsub:#{domain}:nodes", node) == 1
      end

      # Return true if the JID is a registered subscriber to the pubsub topic and
      # messages published to it should be routed to the JID.
      def subscribed?(domain, node, jid)
        jid = JID.new(jid)
        @cluster.query(:sismember, "pubsub:#{domain}:subscribers_#{node}", jid.to_s) == 1
      end

      # Return a list of JIDs subscribed to the pubsub topic.
      def subscribers(domain, node)
        @cluster.query(:smembers, "pubsub:#{domain}:subscribers_#{node}")
      end

      private

      def redis
        @cluster.connection
      end
    end
  end
end
