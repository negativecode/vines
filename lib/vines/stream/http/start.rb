# encoding: UTF-8

module Vines
  class Stream
    class Http
      class Start < State
        def initialize(stream, success=Auth)
          super
        end

        def node(node)
          raise StreamErrors::NotAuthorized unless body?(node)
          if session = Sessions[node['sid']]
            session.resume(stream, node)
          else
            stream.start(node)
            advance
          end
        end
      end
    end
  end
end
