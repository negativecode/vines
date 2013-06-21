# encoding: UTF-8

module Vines
  class Stream
    class Parser < Nokogiri::XML::SAX::Document
      include Nokogiri::XML
      STREAM_NAME = 'stream'.freeze
      STREAM_URI  = 'http://etherx.jabber.org/streams'.freeze
      IGNORE = NAMESPACES.values_at(:client, :component, :server)

      def initialize(&block)
        @listeners, @node = Hash.new {|h, k| h[k] = []}, nil
        @parser = Nokogiri::XML::SAX::PushParser.new(self)
        instance_eval(&block) if block
      end

      [:stream_open, :stream_close, :stanza].each do |name|
        define_method(name) do |&block|
          @listeners[name] << block
        end
      end

      def <<(data)
        @parser << data
        self
      end

      def start_element_namespace(name, attrs=[], prefix=nil, uri=nil, ns=[])
        el = node(name, attrs, prefix, uri, ns)
        if stream?(name, uri)
          notify(:stream_open, el)
        else
          @node << el if @node
          @node = el
        end
      end

      def end_element_namespace(name, prefix=nil, uri=nil)
        if stream?(name, uri)
          notify(:stream_close)
        elsif @node.parent != @node.document
          @node = @node.parent
        else
          notify(:stanza, @node)
          @node = nil
        end
      end

      def characters(chars)
        @node << Text.new(chars, @node.document) if @node
      end
      alias :cdata_block :characters

      private

      def notify(msg, node=nil)
        @listeners[msg].each do |b|
          (node ? b.call(node) : b.call) rescue nil
        end
      end

      def stream?(name, uri)
        name == STREAM_NAME && uri == STREAM_URI
      end

      def node(name, attrs=[], prefix=nil, uri=nil, ns=[])
        ignore = stream?(name, uri) ? [] : IGNORE
        doc = @node ? @node.document : Document.new
        node = doc.create_element(name) do |node|
          attrs.each {|attr| node[attr.localname] = attr.value }
          ns.each {|prefix, uri| node.add_namespace(prefix, uri) unless ignore.include?(uri) }
          doc << node unless @node
        end
        node.namespace = node.add_namespace(prefix, uri) unless ignore.include?(uri)
        node
      end
    end
  end
end
