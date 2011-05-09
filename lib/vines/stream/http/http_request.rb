# encoding: UTF-8

module Vines
  class Stream
    class Http
      class HttpRequest
        attr_accessor :rid

        def initialize(rid)
          @rid = rid
          @received = Time.now
        end

        def expired?
          Time.now - @received > 55
        end
      end
    end
  end
end