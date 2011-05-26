# encoding: UTF-8

module Vines
  class Stanza
    class Iq
      class Si < Iq
        NS = NAMESPACES[:si]
        
        register "/iq[@id and @type='get' or @type='set']/ns:si", 'ns' => NS

        def process
          return if route_iq
            # do nothing
          
        end
      end
    end
  end
end
