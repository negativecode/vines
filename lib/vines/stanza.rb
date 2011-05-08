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

    def broadcast(recipients)
      stream.broadcast(@node, recipients)
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

    def method_missing(method, *args, &block)
      @node.send(method, *args, &block)
    end
  end
end
