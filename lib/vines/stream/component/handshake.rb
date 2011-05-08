# encoding: UTF-8

module Vines
  class Stream
    class Component
      class Handshake < State
        def initialize(stream, success=Ready)
          super
        end

        def node(node)
          raise StreamErrors::NotAuthorized unless handshake?(node)
          stream.write('<handshake/>')
          advance
        end

        private

        def handshake?(node)
          node.name == 'handshake' && node.text == stream.secret
        end
      end
    end
  end
end
