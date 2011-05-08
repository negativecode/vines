# encoding: UTF-8

module Vines
  class Stanza
    class Iq
      class Error < Iq
        register "/iq[@id and @type='error']"

        def process
          return if route_iq
          # do nothing
        end
      end
    end
  end
end
