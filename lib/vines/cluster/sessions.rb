# encoding: UTF-8

module Vines
  class Cluster
    # Manages the cluster node list and user session routing table stored in
    # redis. All cluster nodes share this in-memory database to quickly discover
    # the node hosting a particular user session. Once a session is located,
    # stanzas can be routed to that node via the +Publisher+.
    class Sessions
      include Vines::Log

      NODES = 'nodes'.freeze

      def initialize(cluster)
        @cluster, @nodes = cluster, {}
      end

      # Return the sessions for these JIDs. If a bare JID is used, all sessions
      # for that user will be returned. If a full JID is used, the session for
      # that single connected stream is returned.
      def find(*jids)
        jids.flatten.map do |jid|
          jid = JID.new(jid)
          jid.bare? ? user_sessions(jid) : user_session(jid)
        end.compact.flatten
      end

      # Persist the user's session to the shared redis cache so that other cluster
      # nodes can locate the node hosting this user's connection and route messages
      # to them.
      def save(jid, attrs)
        jid = JID.new(jid)
        session = {node: @cluster.id}.merge(attrs)
        redis.multi
        redis.hset("sessions:#{jid.bare}", jid.resource, session.to_json)
        redis.sadd("node:#{@cluster.id}", jid.to_s)
        redis.exec
      end

      # Remove this user from the cluster routing table so that no further stanzas
      # may be routed to them. This must be called when the user's session is
      # terminated, either by logout or stream disconnect.
      def delete(jid)
        jid = JID.new(jid)
        redis.hget("sessions:#{jid.bare}", jid.resource) do |response|
          if doc = JSON.parse(response) rescue nil
            redis.multi
            redis.hdel("sessions:#{jid.bare}", jid.resource)
            redis.srem("node:#{doc['node']}", jid.to_s)
            redis.exec
          end
        end
      end

      # Remove all user sessions from the routing table associated with the
      # given node ID. Cluster nodes call this themselves during normal shutdown.
      # However, if a node dies without being properly shutdown, the other nodes
      # will cleanup its sessions when they detect the node is offline.
      def delete_all(node)
        @nodes.delete(node)
        redis.smembers("node:#{node}") do |jids|
          redis.multi
          redis.del("node:#{node}")
          redis.hdel(NODES, node)
          jids.each do |jid|
            jid = JID.new(jid)
            redis.hdel("sessions:#{jid.bare}", jid.resource)
          end
          redis.exec
        end
      end

      # Cluster nodes broadcast a heartbeat to other members every second. If we
      # haven't heard from a node in five seconds, assume it's offline and cleanup
      # its session cache for it. Nodes may die abrubtly, without a chance to clear
      # their sessions, so other members cleanup for them.
      def expire
        redis.hset(NODES, @cluster.id, Time.now.to_i)
        redis.hgetall(NODES) do |response|
          now = Time.now
          expired = Hash[*response].select do |node, active|
            offset = @nodes[node] || 0
            (now - offset) - Time.at(active.to_i) > 5
          end.keys
          expired.each {|node| delete_all(node) }
        end
      end

      # Notify the session store that this node is still alive. The node
      # broadcasts its current time, so all cluster members' clocks don't
      # necessarily need to be in sync.
      def poke(node, time)
        offset = Time.now.to_i - time
        @nodes[node] = offset
      end

      private

      # Return all remote sessions for this user's bare JID.
      def user_sessions(jid)
        response = query(:hgetall, "sessions:#{jid.bare}") || []
        Hash[*response].map do |resource, json|
          if session = JSON.parse(json) rescue nil
            session['jid'] = JID.new(jid.node, jid.domain, resource).to_s
          end
          session
        end.compact.reject {|session| session['node'] == @cluster.id }
      end

      # Return the remote session for this full JID or nil if not found.
      def user_session(jid)
        response = query(:hget, "sessions:#{jid.bare}", jid.resource)
        return unless response
        session = JSON.parse(response) rescue nil
        return if session.nil? || session['node'] == @cluster.id
        session['jid'] = jid.to_s
        session
      end

      # Turn an asynchronous redis query into a blocking call by pausing the
      # fiber in which this code is running. Return the result of the query
      # from this method, rather than passing it to a callback block.
      def query(name, *args)
        fiber, yielding = Fiber.current, true
        req = redis.send(name, *args)
        req.errback  { fiber.resume rescue yielding = false }
        req.callback {|response| fiber.resume(response) }
        Fiber.yield if yielding
      end

      def redis
        @cluster.connection
      end
    end
  end
end
