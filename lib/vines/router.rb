# encoding: UTF-8

module Vines
  # The router tracks all stream connections to the server for all clients,
  # servers, and components. It sends stanzas to the correct stream based on
  # the 'to' attribute. Router is a singleton, shared by all streams, that must
  # be accessed with +Config#router+.
  class Router
    EMPTY = [].freeze

    STREAM_TYPES = [:client, :server, :component].freeze

    def initialize(config)
      @config = config
      @clients, @servers, @components = {}, [], []
      @pending = Hash.new {|h,k| h[k] = [] }
    end

    # Returns streams for all connected resources for this JID. A resource is
    # considered connected after it has completed authentication and resource
    # binding.
    def connected_resources(jid, from, proxies=true)
      jid, from = JID.new(jid), JID.new(from)
      return [] unless @config.allowed?(jid, from)

      local = @clients[jid.bare] || EMPTY
      local = local.select {|stream| stream.user.jid == jid } unless jid.bare?
      remote = proxies ? proxies(jid) : EMPTY
      [local, remote].flatten
    end

    # Returns streams for all available resources for this JID. A resource is
    # marked available after it sends initial presence.
    def available_resources(*jids, from)
      clients(jids, from) do |stream|
        stream.available?
      end
    end

    # Returns streams for all interested resources for this JID. A resource is
    # marked interested after it requests the roster.
    def interested_resources(*jids, from)
      clients(jids, from) do |stream|
        stream.interested?
      end
    end

    # Add the connection to the routing table. The connection must return
    # :client, :server, or :component from its +stream_type+ method so the
    # router can properly route stanzas to the stream.
    def <<(stream)
      case stream_type(stream)
      when :client then
        return unless stream.connected?
        stream.user.jid.instance_variable_set("@node", stream.user.jid.node.force_encoding('utf-8'))
        jid = stream.user.jid.bare
        @clients[jid] ||= []
        @clients[jid] << stream
      when :server then @servers << stream
      when :component then @components << stream
      end
    end

    # Remove the connection from the routing table.
    def delete(stream)
      case stream_type(stream)
      when :client then
        return unless stream.connected?
        jid = stream.user.jid.bare
        streams = @clients[jid] || []
        streams.delete(stream)
        @clients.delete(jid) if streams.empty?
      when :server then @servers.delete(stream)
      when :component then @components.delete(stream)
      end
    end

    # Send the stanza to the appropriate remote server-to-server stream
    # or an external component stream.
    def route(stanza)
      to, from = %w[to from].map {|attr| JID.new(stanza[attr]) }
      return unless @config.allowed?(to, from)
      key = [to.domain, from.domain]

      if stream = connection_to(to, from)
        stream.write(stanza)
      elsif @pending.key?(key)
        @pending[key] << stanza
      elsif @config.s2s?(to.domain)
        @pending[key] << stanza
        Vines::Stream::Server.start(@config, to.domain, from.domain) do |stream|
          stream ? send_pending(key, stream) : return_pending(key)
          @pending.delete(key)
        end
      else
        raise StanzaErrors::RemoteServerNotFound.new(stanza, 'cancel')
      end
    end

    # Returns the total number of streams connected to the server.
    def size
      clients = @clients.values.inject(0) {|sum, arr| sum + arr.size }
      clients + @servers.size + @components.size
    end

    private

    # Write all pending stanzas for this domain to the stream. Called after a
    # s2s stream has successfully connected and we need to dequeue all stanzas
    # we received while waiting for the connection to finish.
    def send_pending(key, stream)
      @pending[key].each do |stanza|
        stream.write(stanza)
      end
    end

    # Return all pending stanzas to their senders as remote-server-not-found
    # errors. Called after a s2s stream has failed to connect.
    def return_pending(key)
      @pending[key].each do |stanza|
        to, from = JID.new(stanza['to']), JID.new(stanza['from'])
        xml = StanzaErrors::RemoteServerNotFound.new(stanza, 'cancel').to_xml
        if @config.component?(from)
          connection_to(from, to).write(xml) rescue nil
        else
          connected_resources(from, to).each {|c| c.write(xml) }
        end
      end
    end

    # Return the client streams to which the from address is allowed to
    # contact. Apply the filter block to each stream to narrow the results
    # before returning the streams.
    def clients(jids, from, &filter)
      jids = filter_allowed(jids, from)
      local = @clients.values_at(*jids).compact.flatten.select(&filter)
      proxies = proxies(*jids).select(&filter)
      [local, proxies].flatten
    end

    # Return the bare JIDs from the list that are allowed to talk to
    # the +from+ JID.
    def filter_allowed(jids, from)
      from = JID.new(from)
      jids.flatten.map {|jid| JID.new(jid).bare }
        .select {|jid| @config.allowed?(jid, from) }
    end

    def proxies(*jids)
      return EMPTY unless @config.cluster?
      @config.cluster.remote_sessions(*jids)
    end

    def connection_to(to, from)
      component_stream(to) || server_stream(to, from)
    end

    def component_stream(to)
      @components.select do |stream|
        stream.ready? && stream.remote_domain == to.domain
      end.sample
    end

    def server_stream(to, from)
      @servers.select do |stream|
        stream.ready? &&
          stream.remote_domain == to.domain &&
            stream.domain == from.domain
      end.sample
    end

    def stream_type(connection)
      connection.stream_type.tap do |type|
        unless STREAM_TYPES.include?(type)
          raise ArgumentError, "unexpected stream type: #{type}"
        end
      end
    end
  end
end
