# encoding: UTF-8

module Vines
  class Stream
    class Server
      class TLS < Client::TLS
        def initialize(stream, success=AuthRestart)
          super
        end
      end
    end
  end
end
