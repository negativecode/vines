# encoding: UTF-8

module Vines
  class Stanza
    class Iq
      class ByteStreams < Query
        NS = NAMESPACES[:byte_streams]

        register "/iq[@id and @type='set']/ns:query", 'ns' => NS

        def process
          return if route_iq
        end
      end
    end
  end
end
