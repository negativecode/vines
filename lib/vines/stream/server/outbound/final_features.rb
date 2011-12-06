# encoding: UTF-8

module Vines
  class Stream
    class Server
      class Outbound
        class FinalFeatures < State
          def initialize(stream, success=Server::Ready)
            super
          end

          def node(node)
            raise StreamErrors::NotAuthorized unless empty_features?(node)
            stream.router << stream
            advance
            stream.notify_connected
          end

          private

          def empty_features?(node)
            node.name == 'features' && namespace(node) == NAMESPACES[:stream] && node.elements.empty?
          end
        end
      end
    end
  end
end
