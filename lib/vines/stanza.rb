# encoding: UTF-8

module Vines
  class Stanza
    include Nokogiri::XML

    attr_reader :stream

    EMPTY   = ''.freeze
    FROM    = 'from'.freeze
    MESSAGE = 'message'.freeze
    TO      = 'to'.freeze

    ROUTABLE_STANZAS = %w[message iq presence].freeze

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
      to = JID.new(@node['to'])
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
      recipients = router.available_resources(to, from) if local_jid?(to)

      router.available_resources(from, to).each do |stream|
        el = unavailable(stream.user.jid, to)
        if local_jid?(to)
          recipients.each {|recipient| recipient.write(el) }
        else
          router.route(el)
        end
      end
    end

    # Return an unavailable presence stanza addressed to the given JID.
    def unavailable(from, to)
      doc = Document.new
      doc.create_element('presence',
        'from' => from.to_s,
        'id'   => Kit.uuid,
        'to'   => to.to_s,
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

    def validate_address(attr)
      jid = (self[attr] || EMPTY)
      return if jid.empty?
      JID.new(jid) rescue
        raise StanzaErrors::JidMalformed.new(self, 'modify')
    end
  end
end
