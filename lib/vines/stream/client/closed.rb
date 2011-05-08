# encoding: UTF-8

module Vines
  class Stream
    class Client
      class Closed < State
        def node(node)
          # ignore data received after close_connection
        end
      end
    end
  end
end
