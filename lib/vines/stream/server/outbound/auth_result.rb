# encoding: UTF-8

module Vines
  class Stream
    class Server
      class Outbound
        class AuthResult < State
          def initialize(stream, success=FinalRestart)
            super
          end

          def node(node)
            raise StreamErrors::NotAuthorized unless namespace(node) == NAMESPACES[:sasl]
            case node.name
              when 'success'
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
