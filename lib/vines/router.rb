# encoding: UTF-8

module Vines
  # The router tracks all stream connections to the server for all clients,
  # servers, and components. It sends stanzas to the correct stream based on
  # the 'to' attribute. Router is a singleton, shared by all streams, that must
  # be accessed with +Router.instance+, not +Router.new+.
  class Router
    ROUTABLE_STANZAS = %w[message iq presence].freeze

    STREAM_TYPES = [:client, :server, :component].freeze
    STREAM_TYPES.each do |name|
      define_method "#{name}s" do
        @streams[name]
      end
    end

    @@instance = nil
    def self.instance
      @@instance ||= self.new
    end

    def initialize
      @config = nil
      @streams = Hash.new {|h,k| h[k] = [] }
      @pending = Hash.new {|h,k| h[k] = [] }
    end

    # Returns streams for all connected resources for this JID. A
    # resource is considered connected after it has completed authentication
    # and resource binding.
    def connected_resources(jid, from)
      jid, from = JID.new(jid), JID.new(from)
      clients.select do |stream|
        stream.connected? &&
          jid == (jid.bare? ? stream.user.jid.bare : stream.user.jid) &&
          @config.allowed?(jid, from)
      end
    end

    # Returns streams for all available resources for this JID. A
    # resource is marked available after it sends initial presence.
    # This method accepts a single JID or a list of JIDs.
    def available_resources(*jids, from)
      jids = filter_allowed(jids, from)
      clients.select do |stream|
        stream.available? && jids.include?(stream.user.jid.bare)
      end
    end

    # Returns streams for all interested resources for this JID. A
    # resource is marked interested after it requests the roster.
    # This method accepts a single JID or a list of JIDs.
    def interested_resources(*jids, from)
      jids = filter_allowed(jids, from)
      clients.select do |stream|
        stream.interested? && jids.include?(stream.user.jid.bare)
      end
    end

    # Add the connection to the routing table. The connection must return
    # :client, :server, or :component from its +stream_type+ method so the
    # router can properly route stanzas to the stream.
    def <<(connection)
      type = stream_type(connection)
      @config ||= connection.config
      @streams[type] << connection
    end

    # Remove the connection from the routing table.
    def delete(connection)
      type = stream_type(connection)
      @streams[type].delete(connection)
    end

    # Send the stanza to the appropriate remote server-to-server stream
    # or an external component stream.
    def route(stanza)
      to, from = %w[to from].map {|attr| JID.new(stanza[attr]) }
      return unless @config.allowed?(to, from)

      if stream = connection_to(to.domain)
        stream.write(stanza)
      elsif @pending.key?(to.domain)
        @pending[to.domain] << stanza
      elsif @config.s2s?(to.domain)
        @pending[to.domain] << stanza
        Vines::Stream::Server.start(@config, to.domain, from.domain) do |stream|
          if stream
            @pending[to.domain].each {|s| stream.write(s) }
          else
            @pending[to.domain].each do |s|
              xml = StanzaErrors::RemoteServerNotFound.new(s, 'cancel').to_xml
              connected_resources(s['from']).each {|c| c.write(xml) }
            end
          end
          @pending.delete(to.domain)
        end
      else
        raise StanzaErrors::RemoteServerNotFound.new(stanza, 'cancel')
      end
    end

    # Returns true if this stanza should be processed locally. Returns false
    # if it's destined for a remote domain or external component.
    def local?(stanza)
      return true unless ROUTABLE_STANZAS.include?(stanza.name)
      to = (stanza['to'] || '').strip
      to.empty? || local_jid?(to)
    end

    def local_jid?(*jids)
      @config.local_jid?(*jids)
    end

    # Returns the total number of streams connected to the server.
    def size
      @streams.values.inject(0) {|sum, arr| sum + arr.size }
    end

    private

    # Return the bare JID's from the list that are allowed to talk to
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

    def connection_to(domain)
      (components + servers).find do |stream|
        stream.ready? && stream.remote_domain == domain
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
