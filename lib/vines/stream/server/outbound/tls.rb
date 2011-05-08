# encoding: UTF-8

module Vines
  class Stream
    class Server
      class Outbound
        class TLS < State
          NS = NAMESPACES[:tls]

          def initialize(stream, success=TLSResult)
            super
          end

          def node(node)
            raise StreamErrors::NotAuthorized unless tls?(node)
            stream.write("<starttls xmlns='#{NS}'/>")
            advance
          end

          private

          def tls?(node)
            tls = node.xpath('ns:starttls', 'ns' => NS).any?
            node.name == 'features' && namespace(node) == NAMESPACES[:stream] && tls
          end
        end
      end
    end
  end
end