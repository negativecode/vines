# encoding: UTF-8

module Vines
  class Stream
    class Server
      class Auth < Client::Auth
        def initialize(stream, success=FinalRestart)
          super
        end
      end
    end
  end
end
