# encoding: UTF-8

module Vines
  class Stanza
    include Nokogiri::XML

    attr_reader :stream

    EMPTY = ''.freeze
    FROM, MESSAGE, TO = %w[from message to].map {|s| s.freeze }
    ROUTABLE_STANZAS  = %w[message iq presence].freeze

    @@types = {}

    def self.register(xpath, ns={})
      @@types[[xpath, ns]] = self
    end

    def self.from_node(node, stream)
      # optimize common case
      return Message.new(node, stream) if node.name == MESSAGE
      found = @@types.select {|pair, v| node.xpath(*pair).any? }
        .sort {|a, b| b[0][0].length - a[0][0].length }.first
      found ? found[1].new(node, stream) : nil
    end

    def initialize(node, stream)
      @node, @stream = node, stream
    end

    # Send the stanza to all recipients, stamping it with from and
    # to addresses first.
    def broadcast(recipients)
      @node[FROM] = stream.user.jid.to_s
      recipients.each do |recipient|
        @node[TO] = recipient.user.jid.to_s
        recipient.write(@node)
      end
    end

    # Returns true if this stanza should be processed locally. Returns false
    # if it's destined for a remote domain or external component.
    def local?
      return true unless ROUTABLE_STANZAS.include?(@node.name)
      to = JID.new(@node[TO])
      to.empty? || local_jid?(to)
    end

    def local_jid?(*jids)
      stream.config.local_jid?(*jids)
    end

    def route
      stream.router.route(@node)
    end

    def router
      stream.router
    end

    def storage(domain=stream.domain)
      stream.storage(domain)
    end

    def process
      raise 'subclass must implement'
    end

    # Broadcast unavailable presence from the user's available resources to the
    # recipient's available resources. Route the stanza to a remote server if
    # the recipient isn't hosted locally.
    def send_unavailable(from, to)
      available = router.available_resources(from, to)
      stanzas = available.map {|stream| unavailable(stream.user.jid) }
      broadcast_to_available_resources(stanzas, to)
    end

    # Return an unavailable presence stanza addressed from the given JID.
    def unavailable(from)
      doc = Document.new
      doc.create_element('presence',
        'from' => from.to_s,
        'id'   => Kit.uuid,
        'type' => 'unavailable')
    end

    # Return nil if this stanza has no 'to' attribute. Return a Vines::JID
    # if it contains a valid 'to' attribute.  Raise a JidMalformed error if
    # the JID is invalid.
    def validate_to
      validate_address(TO)
    end

    # Return nil if this stanza has no 'from' attribute. Return a Vines::JID
    # if it contains a valid 'from' attribute.  Raise a JidMalformed error if
    # the JID is invalid.
    def validate_from
      validate_address(FROM)
    end

    def method_missing(method, *args, &block)
      @node.send(method, *args, &block)
    end

    private

    # Send the stanzas to the destination JID, routing to a s2s stream
    # if the address is remote. This method properly stamps the to address
    # on each stanza before it's sent. The caller must set the from address.
    def broadcast_to_available_resources(stanzas, to)
      return if send_to_remote(stanzas, to)
      send_to_recipients(stanzas, stream.available_resources(to))
    end

    # Send the stanzas to the destination JID, routing to a s2s stream
    # if the address is remote. This method properly stamps the to address
    # on each stanza before it's sent. The caller must set the from address.
    def broadcast_to_interested_resources(stanzas, to)
      return if send_to_remote(stanzas, to)
      send_to_recipients(stanzas, stream.interested_resources(to))
    end

    # Route the stanzas to a remote server, stamping a bare JID as the
    # to address. Bare JIDs are required for presence subscription stanzas
    # sent to the remote contact's server. Return true if the stanzas were
    # routed, false if they must be delivered locally.
    def send_to_remote(stanzas, to)
      return false if local_jid?(to)
      to = JID.new(to)
      stanzas.each do |el|
        el[TO] = to.bare.to_s
        router.route(el)
      end
      true
    end

    # Send the stanzas to the local recipient streams, stamping a full JID as
    # the to address. It's important to use full JIDs, even when sending to
    # local clients, because the stanzas may be routed to other cluster nodes
    # for delivery. We need the receiving cluster node to send the stanza just
    # to this full JID, not to lookup all JIDs for this user.
    def send_to_recipients(stanzas, recipients)
      recipients.each do |recipient|
        stanzas.each do |el|
          el[TO] = recipient.user.jid.to_s
          recipient.write(el)
        end
      end
    end

    # Return true if the to and from JIDs are allowed to communicate with one
    # another based on the cross_domain_messages setting in conf/config.rb. If
    # a domain's users are isolated to sending messages only within their own
    # domain, pubsub stanzas must not be processed from remote JIDs.
    def allowed?
      stream.config.allowed?(validate_to, stream.user.jid)
    end

    def validate_address(attr)
      jid = (self[attr] || EMPTY)
      return if jid.empty?
      JID.new(jid)
    rescue
      raise StanzaErrors::JidMalformed.new(self, 'modify')
    end
  end
end
