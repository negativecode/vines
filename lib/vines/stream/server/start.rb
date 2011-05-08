# encoding: UTF-8

module Vines
  class Stream
    class Server
      class Start < Client::Start
        def initialize(stream, success=TLS)
          super
        end
      end
    end
  end
end
