# encoding: UTF-8

module Vines
  class Stanza
    class Presence
      class Unavailable < Presence
        register "/presence[@type='unavailable']"

        def process
          inbound? ? inbound_broadcast_presence : outbound_broadcast_presence
        end
      end
    end
  end
end
