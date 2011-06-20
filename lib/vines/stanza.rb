# encoding: UTF-8

module Vines
  class Stanza
    include Nokogiri::XML

    attr_reader :stream

    MESSAGE = 'message'.freeze
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
      @node['from'] = stream.user.jid.to_s
      recipients.each do |recipient|
        @node['to'] = recipient.user.jid.to_s
        recipient.write(@node)
      end
    end

    def local?
      stream.router.local?(@node)
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
      router.available_resources(from).each do |stream|
        el = unavailable(stream.user.jid, to)
        if router.local_jid?(to)
          router.available_resources(to).each do |recipient|
            recipient.write(el)
          end
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

    def method_missing(method, *args, &block)
      @node.send(method, *args, &block)
    end
  end
end
