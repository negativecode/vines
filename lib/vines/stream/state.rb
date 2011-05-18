# encoding: UTF-8

module Vines
  class Stream

    # The base class of Stream state machines. States know how to process XML
    # nodes and advance to their next valid state or fail the stream.
    class State
      include Nokogiri::XML
      include Vines::Log

      attr_accessor :stream

      BODY   = 'body'.freeze
      STREAM = 'stream'.freeze

      def initialize(stream, success=nil)
        @stream, @success = stream, success
      end

      def node(node)
        raise 'subclass must implement'
      end

      def ==(state)
        self.class == state.class
      end

      def eql?(state)
        state.is_a?(State) && self == state
      end

      def hash
        self.class.hash
      end

      private

      def advance
        stream.advance(@success.new(stream))
      end

      def stream?(node)
        node.name == STREAM && namespace(node) == NAMESPACES[:stream]
      end

      def body?(node)
        node.name == BODY && namespace(node) == NAMESPACES[:http_bind]
      end

      def namespace(node)
        node.namespace ? node.namespace.href : nil
      end

      def to_stanza(node)
        Stanza.from_node(node, stream)
      end
    end
  end
end