# encoding: UTF-8

module Vines
  class Stream
    class Server
      class Outbound
        class AuthResult < State
          SUCCESS = 'success'.freeze
          FAILURE = 'failure'.freeze

          def initialize(stream, success=FinalRestart)
            super
          end

          def node(node)
            raise StreamErrors::NotAuthorized unless namespace(node) == NAMESPACES[:sasl]
            case node.name
            when SUCCESS
              stream.start(node)
              stream.reset
              advance
            when FAILURE
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
