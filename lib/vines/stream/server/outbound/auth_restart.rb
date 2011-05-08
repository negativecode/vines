# encoding: UTF-8

module Vines
  class Stream
    class Server
      class Outbound
        class AuthRestart < State
          def initialize(stream, success=Auth)
            super
          end

          def node(node)
            raise StreamErrors::NotAuthorized unless stream?(node)
            advance
          end
        end
      end
    end
  end
end
