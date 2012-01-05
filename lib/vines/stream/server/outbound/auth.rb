# encoding: UTF-8

module Vines
  class Stream
    class Server
      class Outbound
        class Auth < State
          NS = NAMESPACES[:sasl]

          def initialize(stream, success=AuthResult)
            super
          end

          def node(node)
            raise StreamErrors::NotAuthorized unless external?(node)
            authz = [stream.domain].pack("m0")
            stream.write(%Q{<auth xmlns="#{NS}" mechanism="EXTERNAL">#{authz}</auth>})
            advance
          end

          private

          def external?(node)
            external = node.xpath("ns:mechanisms/ns:mechanism[text()='EXTERNAL']", 'ns' => NS).any?
            node.name == 'features' && namespace(node) == NAMESPACES[:stream] && external
          end
        end
      end
    end
  end
end
