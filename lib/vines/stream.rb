# encoding: UTF-8

module Vines
  # The base class for various XMPP streams (c2s, s2s, component, http),
  # containing behavior common to all streams like rate limiting, stanza
  # parsing, and stream error handling.
  class Stream < EventMachine::Connection
    include Vines::Log

    ERROR = 'error'.freeze
    PAD   = 20

    attr_accessor :user

    def post_init
      router << self
      @remote_addr, @local_addr = [get_peername, get_sockname].map do |addr|
        addr ? Socket.unpack_sockaddr_in(addr)[0, 2].reverse.join(':') : 'unknown'
      end
      @user, @closed, @stanza_size = nil, false, 0
      @bucket = TokenBucket.new(100, 10)
      @store = Store.new

      @nodes = EM::Queue.new
      process_node_queue

      @parser = Parser.new.tap do |p|
        p.stream_open {|node| @nodes.push(node) }
        p.stream_close { close_connection }
        p.stanza {|node| @nodes.push(node) }
      end
      log.info { "%s %21s -> %s" %
        ['Stream connected:'.ljust(PAD), @remote_addr, @local_addr] }
    end

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

    # Send the stanza to all recipients, stamping it with from and
    # to addresses first.
    def broadcast(stanza, recipients)
      stanza['from'] = @user.jid.to_s
      recipients.each do |recipient|
        stanza['to'] = recipient.user.jid.to_s
        recipient.write(stanza)
      end
    end

    # Returns the storage system for the domain. If no domain is given,
    # the stream's storage mechanism is returned.
    def storage(domain=@domain)
      @config.vhosts[domain]
    end

    # Reload the user's information into their active connections. Call this
    # after storage.save_user() to sync the new user state with their other
    # connections.
    def update_user_streams(user)
      router.connected_resources(user.jid.bare).each do |stream|
        stream.user.update_from(user)
      end
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
      cert, key = tls_files
      start_tls(:private_key_file => key, :cert_chain_file => cert, :verify_peer => true)
    end

    # Returns true if the TLS certificate and private key files for this domain
    # exist and can be used to encrypt this stream.
    def encrypt?
      tls_files.all? {|f| File.exists?(f) }
    end

    def unbind
      router.delete(self)
      log.info { "%s %21s -> %s" %
        ['Stream disconnected:'.ljust(PAD), @remote_addr, @local_addr] }
      log.info { "Streams connected: #{router.size}" }
    end

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
        write(e.to_xml)
        close_stream
      else
        log.error(e)
        write(StreamErrors::InternalServerError.new.to_xml)
        close_stream
      end
    end

    def router
      Router.instance
    end

    private

    def close_stream
      write('</stream:stream>')
      close_connection_after_writing
    end

    def error?(node)
      ns = node.namespace ? node.namespace.href : nil
      node.name == ERROR && ns == NAMESPACES[:stream]
    end

    # Schedule a queue pop on the EM thread to handle the next element.
    # This provides the in-order stanza processing guarantee required by
    # RFC 6120 section 10.1.
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
        @state.node(node)
      end
    rescue Exception => e
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

    def tls_files
      %w[crt key].map {|ext| File.join(VINES_ROOT, 'conf', 'certs', "#{@domain}.#{ext}") }
    end
  end
end
