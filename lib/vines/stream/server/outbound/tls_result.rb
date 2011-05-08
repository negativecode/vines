# encoding: UTF-8

module Vines
  class Stream
    class Server
      class Outbound
        class TLSResult < State
          NS = NAMESPACES[:tls]

          def initialize(stream, success=AuthRestart)
            super
          end

          def node(node)
            raise StreamErrors::NotAuthorized unless namespace(node) == NS
            case node.name
              when 'proceed'
                stream.encrypt
                stream.start(node)
                advance
              when 'failure'
                stream.close_connection
              else
                raise StreamErrors::NotAuthorized
            end
          end
        end
      end
    end
  end
end