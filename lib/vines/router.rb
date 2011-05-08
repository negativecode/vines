# encoding: UTF-8

module Vines
  # The router tracks all stream connections to the server for all clients,
  # servers, and components. It sends stanzas to the correct stream based on
  # the 'to' attribute. Router is a singleton, shared by all streams, that must
  # be accessed with +Router.instance+, not +Router.new+.
  class Router
    ROUTABLE_STANZAS = %w[message iq presence].freeze

    @@instance = nil
    def self.instance
      @@instance ||= Router.new
    end

    def initialize
      @config = nil
      @streams = Hash.new {|h,k| h[k] = [] }
      @pending = Hash.new {|h,k| h[k] = [] }
    end

    %w[Client Server Component].each do |klass|
      name = klass.split(/(?=[A-Z])/).join('_').downcase
      define_method(name + 's') do
        @streams["Vines::Stream::#{klass}"]
      end
    end

    def http_states
      @streams["Vines::Stream::Http::HttpState"]
    end

    # Returns streams for all connected resources for this JID. A
    # resource is considered connected after it has completed authentication
    # and resource binding.
    def connected_resources(jid)
      jid = JID.new(jid)
      (clients + http_states).select do |stream|
        stream.connected? && jid == (jid.bare? ? stream.user.jid.bare : stream.user.jid)
      end
    end

    # Returns streams for all available resources for this JID. A
    # resource is marked available after it sends initial presence.
    # This method accepts a single JID or a list of JIDs.
    def available_resources(*jid)
      ids = jid.flatten.map {|jid| JID.new(jid).bare }
      (clients + http_states).select do |stream|
        stream.available? && ids.include?(stream.user.jid.bare)
      end
    end

    # Returns streams for all interested resources for this JID. A
    # resource is marked interested after it requests the roster.
    # This method accepts a single JID or a list of JIDs.
    def interested_resources(*jid)
      ids = jid.flatten.map {|jid| JID.new(jid).bare }
      (clients + http_states).select do |stream|
        stream.interested? && ids.include?(stream.user.jid.bare)
      end
    end

    # Add the connection to the routing table.
    def <<(connection)
      @config ||= connection.config
      @streams[connection.class.to_s] << connection
    end

    # Remove the connection from the routing table.
    def delete(connection)
      @streams[connection.class.to_s].delete(connection)
    end

    # Send the stanza to the appropriate remote server-to-server stream
    # or an external component stream.
    def route(stanza)
      to, from = %w[to from].map {|attr| JID.new(stanza[attr]) }
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

    def local_jid?(jid)
      @config.vhost?(JID.new(jid).domain)
    end

    # Returns the total number of streams connected to the server.
    def size
      @streams.values.inject(0) {|sum, arr| sum + arr.size }
    end

    private

    def connection_to(domain)
      (components + servers).find do |stream|
        stream.ready? && stream.remote_domain == domain
      end
    end
  end
end
