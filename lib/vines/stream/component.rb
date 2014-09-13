# encoding: UTF-8

module Vines
  class Stream

    # Implements the XMPP protocol for trusted, external component (XEP-0114)
    # streams. This serves connected streams using the jabber:component:accept
    # namespace.
    class Component < Stream
      attr_reader :remote_domain

      def initialize(config)
        super
        @remote_domain = nil
        @stream_id = Kit.uuid
        advance(Start.new(self))
      end

      def max_stanza_size
        config[:component].max_stanza_size
      end

      def ready?
        state.class == Component::Ready
      end

      def stream_type
        :component
      end

      def start(node)
        @remote_domain = node['to']
        send_stream_header
        raise StreamErrors::ImproperAddressing unless valid_address?(@remote_domain)
        raise StreamErrors::HostUnknown unless config.component?(@remote_domain)
        raise StreamErrors::InvalidNamespace unless node.namespaces['xmlns'] == NAMESPACES[:component]
        raise StreamErrors::InvalidNamespace unless node.namespaces['xmlns:stream'] == NAMESPACES[:stream]
      end

      def secret
        password = config.component_password(@remote_domain)
        Digest::SHA1.hexdigest(@stream_id + password)
      end

      private

      def send_stream_header
        attrs = {
          'xmlns'        => NAMESPACES[:component],
          'xmlns:stream' => NAMESPACES[:stream],
          'id'           => @stream_id,
          'from'         => @remote_domain
        }
        write "<stream:stream %s>" % attrs.to_a.map{|k,v| "#{k}='#{v}'"}.join(' ')
      end
    end
  end
end
