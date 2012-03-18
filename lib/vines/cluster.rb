# encoding: UTF-8

module Vines
  # Server instances may be connected to one another in a cluster so they
  # can host a single chat domain, or set of domains, across many servers,
  # transparently to users. A redis database is used for the session routing
  # table, mapping JIDs to their node's location. Redis pubsub channels are
  # used to communicate amongst nodes.
  #
  # Using a shared in-memory cache, like redis, rather than synchronizing the
  # cache to each node, allows us to add cluster nodes dynamically, without
  # updating all other nodes' config files. It also greatly reduces the amount
  # of memory required by the chat server processes.
  class Cluster
    include Vines::Log

    attr_reader :id

    %w[host port database password].each do |name|
      define_method(name) do |*args|
        if args.first
          @connection.send("#{name}=", args.first)
        else
          @connection.send(name)
        end
      end
    end

    def initialize(config, &block)
      @config, @id = config, Kit.uuid
      @connection = Connection.new
      @sessions = Sessions.new(self)
      @publisher = Publisher.new(self)
      @subscriber = Subscriber.new(self)
      @pubsub = PubSub.new(self)
      instance_eval(&block)
    end

    # Join this node to the cluster by broadcasting its state to the
    # other nodes, subscribing to redis channels, and scheduling periodic
    # heartbeat broadcasts. This method must be called after initialize
    # or this node will not be a cluster member.
    def start
      @connection.connect
      @publisher.broadcast(:online)
      @subscriber.subscribe

      EM.add_periodic_timer(1) { heartbeat }

      at_exit do
        @publisher.broadcast(:offline)
        @sessions.delete_all(@id)
      end
    end

    # Returns any streams hosted at remote nodes for these JIDs. The streams act
    # like normal EM::Connections, but are actually proxies that route stanzas
    # over redis pubsub channels to remote nodes.
    def remote_sessions(*jids)
      @sessions.find(*jids).map do |session|
        StreamProxy.new(self, session)
      end
    end

    # Persist the user's session to the shared redis cache so that other cluster
    # nodes can locate the node hosting this user's connection and route messages
    # to them.
    def save_session(jid, attrs)
      @sessions.save(jid, attrs)
    end

    # Remove this user from the cluster routing table so that no further stanzas
    # may be routed to them. This must be called when the user's session is
    # terminated, either by logout or stream disconnect.
    def delete_session(jid)
      @sessions.delete(jid)
    end

    # Remove all user sessions from the routing table associated with the
    # given node ID. Cluster nodes call this themselves during normal shutdown.
    # However, if a node dies without being properly shutdown, the other nodes
    # will cleanup its sessions when they detect the node is offline.
    def delete_sessions(node)
      @sessions.delete_all(node)
    end

    # Notify the session store that this node is still alive. The node
    # broadcasts its current time, so all cluster members' clocks don't
    # necessarily need to be in sync.
    def poke(node, time)
      @sessions.poke(node, time)
    end

    # Send the stanza to the node hosting the user's session. The stanza is
    # published to the channel to which the remote node is listening for
    # messages.
    def route(stanza, node)
      @publisher.route(stanza, node)
    end

    # Notify the remote node that the user's roster has changed and it should
    # reload the user from storage.
    def update_user(jid, node)
      @publisher.update_user(jid, node)
    end

    # Return the shared redis connection for most queries to use.
    def connection
      @connection.connect
    end

    # Create a new redis connection.
    def connect
      @connection.create
    end

    # Turn an asynchronous redis query into a blocking call by pausing the
    # fiber in which this code is running. Return the result of the query
    # from this method, rather than passing it to a callback block.
    def query(name, *args)
      fiber, yielding = Fiber.current, true
      req = connection.send(name, *args)
      req.errback  { fiber.resume rescue yielding = false }
      req.callback {|response| fiber.resume(response) }
      Fiber.yield if yielding
    end

    # Return the connected streams for this user, without any proxy streams
    # to remote cluster nodes (locally connected streams only).
    def connected_resources(jid)
      @config.router.connected_resources(jid, jid, false)
    end

    # Return the Storage implementation for this domain or nil if the
    # domain is not hosted here.
    def storage(domain)
      @config.storage(domain)
    end

    # Create a pubsub topic (a.k.a. node), in the given domain, to which
    # messages may be published. The domain argument will be one of the
    # configured pubsub subdomains in conf/config.rb (e.g. games.wonderland.lit,
    # topics.wonderland.lit, etc).
    def add_pubsub_node(domain, node)
      @pubsub.add_node(domain, node)
    end

    # Remove a pubsub topic so messages may no longer be broadcast to it.
    def delete_pubsub_node(domain, node)
      @pubsub.delete_node(domain, node)
    end

    # Subscribe the JID to the pubsub topic so it will receive any messages
    # published to it.
    def subscribe_pubsub(domain, node, jid)
      @pubsub.subscribe(domain, node, jid)
    end

    # Unsubscribe the JID from the pubsub topic, deregistering its interest
    # in receiving any messages published to it.
    def unsubscribe_pubsub(domain, node, jid)
      @pubsub.unsubscribe(domain, node, jid)
    end

    # Unsubscribe the JID from all pubsub topics. This is useful when the
    # JID's session ends by logout or disconnect.
    def unsubscribe_all_pubsub(domain, jid)
      @pubsub.unsubscribe_all(domain, jid)
    end

    # Return true if the pubsub topic exists and messages may be published to it.
    def pubsub_node?(domain, node)
      @pubsub.node?(domain, node)
    end

    # Return true if the JID is a registered subscriber to the pubsub topic and
    # messages published to it should be routed to the JID.
    def pubsub_subscribed?(domain, node, jid)
      @pubsub.subscribed?(domain, node, jid)
    end

    # Return a list of JIDs subscribed to the pubsub topic.
    def pubsub_subscribers(domain, node)
      @pubsub.subscribers(domain, node)
    end

    private

    # Call this method once per second to broadcast this node's heartbeat and
    # expire stale user sessions. This method must not raise exceptions or the
    # timer will stop.
    def heartbeat
      @publisher.broadcast(:heartbeat)
      @sessions.expire
    rescue => e
      log.error("Cluster session cleanup failed: #{e}")
    end

    # StreamProxy behaves like an EM::Connection so that stanzas may be sent to
    # remote nodes just as they are to locally connected streams. The rest of the
    # system doesn't know or care that these "streams" send their traffic over
    # redis pubsub channels.
    class StreamProxy
      attr_reader :user

      def initialize(cluster, session)
        @cluster, @user = cluster, UserProxy.new(cluster, session)
        @node, @available, @interested, @presence =
          session.values_at('node', 'available', 'interested', 'presence')

        unless @presence.nil? || @presence.empty?
          @presence = Nokogiri::XML(@presence).root rescue nil
        end
      end

      def available?
        @available
      end

      def interested?
        @interested
      end

      def last_broadcast_presence
        @presence
      end

      def write(stanza)
        @cluster.route(stanza, @node)
      end
    end

    # Proxy User#update_from calls to remote cluster nodes over redis
    # pubsub channels.
    class UserProxy < User
      def initialize(cluster, session)
        super(jid: session['jid'])
        @cluster, @node = cluster, session['node']
      end

      def update_from(user)
        @cluster.update_user(@jid.bare, @node)
      end
    end
  end
end
