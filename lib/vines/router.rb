# encoding: UTF-8

module Vines
  # The router tracks all stream connections to the server for all clients,
  # servers, and components. It sends stanzas to the correct stream based on
  # the 'to' attribute. Router is a singleton, shared by all streams, that must
  # be accessed with +Config#router+.
  class Router
    EMPTY = [].freeze

    STREAM_TYPES = [:client, :server, :component].freeze
    STREAM_TYPES.each do |name|
      define_method "#{name}s" do
        @streams[name]
      end
    end

    def initialize(config)
      @config = config
      @streams = Hash.new {|h,k| h[k] = [] }
      @pending = Hash.new {|h,k| h[k] = [] }
    end

    # Returns streams for all connected resources for this JID. A resource is
    # considered connected after it has completed authentication and resource
    # binding.
    def connected_resources(jid, from, proxies=true)
      jid, from = JID.new(jid), JID.new(from)
      return [] unless @config.allowed?(jid, from)
      local = clients.select do |stream|
        stream.connected? &&
          jid == (jid.bare? ? stream.user.jid.bare : stream.user.jid)
      end
      [local, proxies ? proxies(jid) : []].flatten
    end

    # Returns streams for all available resources for this JID. A resource is
    # marked available after it sends initial presence. This method accepts a
    # single JID or a list of JIDs.
    def available_resources(*jids, from)
      jids = filter_allowed(jids, from)
      local = clients.select do |stream|
        stream.available? && jids.include?(stream.user.jid.bare)
      end
      proxies = proxies(*jids.keys).select {|stream| stream.available? }
      [local, proxies].flatten
    end

    # Returns streams for all interested resources for this JID. A resource is
    # marked interested after it requests the roster. This method accepts a
    # single JID or a list of JIDs.
    def interested_resources(*jids, from)
      jids = filter_allowed(jids, from)
      local = clients.select do |stream|
        stream.interested? && jids.include?(stream.user.jid.bare)
      end
      proxies = proxies(*jids.keys).select {|stream| stream.interested? }
      [local, proxies].flatten
    end

    # Add the connection to the routing table. The connection must return
    # :client, :server, or :component from its +stream_type+ method so the
    # router can properly route stanzas to the stream.
    def <<(stream)
      type = stream_type(stream)
      @streams[type] << stream
    end

    # Remove the connection from the routing table.
    def delete(stream)
      type = stream_type(stream)
      @streams[type].delete(stream)
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
      @streams.values.inject(0) {|sum, arr| sum + arr.size }
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

    # Return the bare JIDs from the list that are allowed to talk to
    # the +from+ JID. Store them in a Hash for fast +include?+ checks.
    def filter_allowed(jids, from)
      from = JID.new(from)
      {}.tap do |ids|
        jids.flatten.each do |jid|
          jid = JID.new(jid).bare
          ids[jid] = nil if @config.allowed?(jid, from)
        end
      end
    end

    def proxies(*jids)
      return EMPTY unless @config.cluster?
      @config.cluster.remote_sessions(*jids)
    end

    def connection_to(to, from)
      component_stream(to) || server_stream(to, from)
    end

    def component_stream(to)
      components.find do |stream|
        stream.ready? && stream.remote_domain == to.domain
      end
    end

    def server_stream(to, from)
      servers.find do |stream|
        stream.ready? &&
          stream.remote_domain == to.domain &&
            stream.domain == from.domain
      end
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
