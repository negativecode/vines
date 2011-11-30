# encoding: UTF-8

module Vines
  class Config
    # Provides the configuration DSL to conf/config.rb for pubsub subdomains and
    # exposes the storage and notification systems that the pubsub stanzas need
    # to process. This class hides the complexity of determining pubsub behavior
    # in a standalone vs. clustered chat server environment from the stanzas.
    class PubSub
      def initialize(config, name)
        @config, @name = config, name
        @nodes = {}
      end

      def add_node(id)
        if @config.cluster?
          @config.cluster.add_pubsub_node(@name, id)
        else
          @nodes[id] ||= Set.new
        end
      end

      def delete_node(id)
        if @config.cluster?
          @config.cluster.delete_pubsub_node(@name, id)
        else
          @nodes.delete(id)
        end
      end

      def subscribe(node, jid)
        return unless node?(node) && @config.allowed?(jid, @name)
        if @config.cluster?
          @config.cluster.subscribe_pubsub(@name, node, jid)
        else
          @nodes[node] << JID.new(jid)
        end
      end

      def unsubscribe(node, jid)
        return unless node?(node)
        if @config.cluster?
          @config.cluster.unsubscribe_pubsub(@name, node, jid)
        else
          @nodes[node].delete(JID.new(jid))
          delete_node(node) if subscribers(node).empty?
        end
      end

      def unsubscribe_all(jid)
        if @config.cluster?
          @config.cluster.unsubscribe_all_pubsub(@name, jid)
        else
          @nodes.keys.each do |node|
            unsubscribe(node, jid)
          end
        end
      end

      def node?(node)
        if @config.cluster?
          @config.cluster.pubsub_node?(@name, node)
        else
          @nodes.key?(node)
        end
      end

      def subscribed?(node, jid)
        return false unless node?(node)
        if @config.cluster?
          @config.cluster.pubsub_subscribed?(@name, node, jid)
        else
          @nodes[node].include?(JID.new(jid))
        end
      end

      def publish(node, stanza)
        stanza['id'] = Kit.uuid
        stanza['from'] = @name

        local, remote = subscribers(node).partition {|jid| @config.local_jid?(jid) }

        local.flat_map do |jid|
          @config.router.connected_resources(jid, @name)
        end.each do |recipient|
          stanza['to'] = recipient.user.jid.to_s
          recipient.write(stanza)
        end

        remote.each do |jid|
          el = stanza.clone
          el['to'] = jid.to_s
          @config.router.route(el) rescue nil # ignore RemoteServerNotFound
        end
      end

      private

      def subscribers(node)
        if @config.cluster?
          @config.cluster.pubsub_subscribers(@name, node)
        else
          @nodes[node] || []
        end
      end
    end
  end
end
