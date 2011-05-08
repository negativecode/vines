# encoding: UTF-8

module Vines
  class Stream
    class Component
      class Start < State
        def initialize(stream, success=Handshake)
          super
        end

        def node(node)
          raise StreamErrors::NotAuthorized unless stream?(node)
          stream.start(node)
          advance
        end
      end
    end
  end
end
