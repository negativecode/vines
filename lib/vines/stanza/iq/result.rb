# encoding: UTF-8

module Vines
  class Stanza
    class Iq
      class Result < Iq
        register "/iq[@id and @type='result']"

        def process
          return if route_iq
          # do nothing
        end
      end
    end
  end
end
