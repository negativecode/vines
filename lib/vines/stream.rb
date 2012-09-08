# encoding: UTF-8

module Vines
  # The base class for various XMPP streams (c2s, s2s, component, http),
  # containing behavior common to all streams like rate limiting, stanza
  # parsing, and stream error handling.
  class Stream < EventMachine::Connection
    include Vines::Log

    ERROR = 'error'.freeze
    PAD   = 20

    attr_reader   :config, :domain
    attr_accessor :user

    def initialize(config)
      @config = config
    end

    def post_init
      @remote_addr, @local_addr = addresses
      @user, @closed, @stanza_size = nil, false, 0
      @bucket = TokenBucket.new(100, 10)
      @store = Store.new(@config.certs)
      @nodes = EM::Queue.new
      process_node_queue
      create_parser
      log.info { "%s %21s -> %s" %
        ['Stream connected:'.ljust(PAD), @remote_addr, @local_addr] }
    end

    # Initialize a new XML parser for this connection. This is called when the
    # stream is first connected as well as for stream restarts during
    # negotiation. Subclasses can override this method to provide a different
    # type of parser (e.g. HTTP).
    def create_parser
      @parser = Parser.new.tap do |p|
        p.stream_open {|node| @nodes.push(node) }
        p.stream_close { close_connection }
        p.stanza {|node| @nodes.push(node) }
      end
    end

    # Advance the state machine into the +Closed+ state so any remaining queued
    # nodes are not processed while we're waiting for EM to actually close the
    # connection.
    def close_connection(after_writing=false)
      super
      @closed = true
      advance(Client::Closed.new(self))
    end

    def receive_data(data)
      return if @closed
      @stanza_size += data.bytesize
      if @stanza_size < max_stanza_size
        @parser << data rescue error(StreamErrors::NotWellFormed.new)
      else
        error(StreamErrors::PolicyViolation.new('max stanza size reached'))
      end
    end

    # Reset the connection's XML parser when a new <stream:stream> header
    # is received.
    def reset
      create_parser
    end

    # Returns the storage system for the domain. If no domain is given,
    # the stream's storage mechanism is returned.
    def storage(domain=nil)
      @config.storage(domain || self.domain)
    end

    # Returns the Vines::Config::Host virtual host for the stream's domain.
    def vhost
      @config.vhost(domain)
    end

    # Reload the user's information into their active connections. Call this
    # after storage.save_user() to sync the new user state with their other
    # connections.
    def update_user_streams(user)
      connected_resources(user.jid.bare).each do |stream|
        stream.user.update_from(user)
      end
    end

    def connected_resources(jid)
      router.connected_resources(jid, user.jid)
    end

    def available_resources(*jid)
      router.available_resources(*jid, user.jid)
    end

    def interested_resources(*jid)
      router.interested_resources(*jid, user.jid)
    end

    def ssl_verify_peer(pem)
      # EM is supposed to close the connection when this returns false,
      # but it only does that for inbound connections, not when we
      # make a connection to another server.
      @store.trusted?(pem).tap do |trusted|
        close_connection unless trusted
      end
    end

    def cert_domain_matches?(domain)
      @store.domain?(get_peer_cert, domain)
    end

    # Send the data over the wire to this client.
    def write(data)
      log_node(data, :out)
      if data.respond_to?(:to_xml)
        data = data.to_xml(:indent => 0)
      end
      send_data(data)
    end

    def encrypt
      cert, key = @store.files_for_domain(domain)
      start_tls(cert_chain_file: cert, private_key_file: key, verify_peer: true)
    end

    # Returns true if the TLS certificate and private key files for this domain
    # exist and can be used to encrypt this stream.
    def encrypt?
      !@store.files_for_domain(domain).nil?
    end

    def unbind
      router.delete(self)
      log.info { "%s %21s -> %s" %
        ['Stream disconnected:'.ljust(PAD), @remote_addr, @local_addr] }
      log.info { "Streams connected: #{router.size}" }
    end

    # Advance the stream's state machine to the new state. XML nodes received
    # by the stream will be passed to this state's +node+ method.
    def advance(state)
      @state = state
    end

    # Stream level errors close the stream while stanza and SASL errors are
    # written to the client and leave the stream open. All exceptions should
    # pass through this method for consistent handling.
    def error(e)
      case e
      when SaslError, StanzaError
        write(e.to_xml)
      when StreamError
        send_stream_error(e)
        close_stream
      else
        log.error(e)
        send_stream_error(StreamErrors::InternalServerError.new)
        close_stream
      end
    end

    def router
      @config.router
    end

    private

    # Return the remote and local socket addresses used by this connection.
    def addresses
      [get_peername, get_sockname].map do |addr|
        addr ? Socket.unpack_sockaddr_in(addr)[0, 2].reverse.join(':') : 'unknown'
      end
    end

    # Write the StreamError's xml to the stream. Subclasses can override
    # this method with custom error writing behavior.
    def send_stream_error(e)
      write(e.to_xml)
    end

    # Write a closing stream tag to the stream then close the stream. Subclasses
    # can override this method for custom close behavior.
    def close_stream
      write('</stream:stream>')
      close_connection_after_writing
    end

    def error?(node)
      ns = node.namespace ? node.namespace.href : nil
      node.name == ERROR && ns == NAMESPACES[:stream]
    end

    # Schedule a queue pop on the EM thread to handle the next element. This
    # guarantees all stanzas received on this stream are processed in order.
    # http://tools.ietf.org/html/rfc6120#section-10.1
    def process_node_queue
      @nodes.pop do |node|
        Fiber.new do
          process_node(node)
          process_node_queue
        end.resume unless @closed
      end
    end

    def process_node(node)
      log_node(node, :in)
      @stanza_size = 0
      enforce_rate_limit
      if error?(node)
        close_stream
      else
        state.node(node)
      end
    rescue => e
      error(e)
    end

    def enforce_rate_limit
      unless @bucket.take(1)
        raise StreamErrors::PolicyViolation.new('rate limit exceeded')
      end
    end

    def log_node(node, direction)
      return unless log.debug?
      from, to = @remote_addr, @local_addr
      from, to = to, from if direction == :out
      label = (direction == :out) ? 'Sent' : 'Received'
      log.debug("%s %21s -> %s\n%s\n" %
        ["#{label} stanza:".ljust(PAD), from, to, node])
    end

    # Returns the current +State+ of the stream's state machine. Provided as a
    # method so subclasses can override the behavior.
    def state
      @state
    end

    # Return +true+ if this is a valid domain-only JID that can be used in
    # stream initiation stanza headers.
    def valid_address?(jid)
      JID.new(jid).domain? rescue false
    end
  end
end
