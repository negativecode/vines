# encoding: UTF-8

module Vines
  class Stanza
    class Iq
      # Session support is deprecated, but Adium requires it, so reply with an
      # iq result stanza.
      class Session < Iq
        register "/iq[@id and @type='set']/ns:session", 'ns' => NAMESPACES[:session]

        def process
          stream.write(to_result)
        end
      end
    end
  end
end
