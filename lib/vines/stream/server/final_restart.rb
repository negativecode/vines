# encoding: UTF-8

module Vines
  class Stream
    class Server
      class FinalRestart < State
        def initialize(stream, success=Ready)
          super
        end

        def node(node)
          raise StreamErrors::NotAuthorized unless stream?(node)
          stream.start(node)
          stream.write('<stream:features/>')
          stream.router << stream
          advance
        end
      end
    end
  end
end
