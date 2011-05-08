# encoding: UTF-8

module Vines
  class Stanza
    class Iq
      class Ping < Iq
        register "/iq[@id and @type='get']/ns:ping", 'ns' => NAMESPACES[:ping]

        def process
          return if route_iq
          stream.write(to_result)
        end
      end
    end
  end
end
