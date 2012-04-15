# encoding: UTF-8

module Vines
  class Stream
    class Server
      class AuthRestart < Client::AuthRestart
        def initialize(stream, success=Auth)
          super
        end
      end
    end
  end
end
