# encoding: UTF-8

module Vines
  class Stanza
    class Presence
      class Error < Presence
        register "/presence[@type='error']"

        def process
          inbound? ? process_inbound : process_outbound
        end

        def process_outbound
          # FIXME Implement error handling
        end

        def process_inbound
          # FIXME Implement error handling
        end
      end
    end
  end
end
