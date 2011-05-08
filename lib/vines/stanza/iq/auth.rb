# encoding: UTF-8

module Vines
  class Stanza
    class Iq
      class Auth < Query
        register "/iq[@id and @type='get']/ns:query", 'ns' => NAMESPACES[:non_sasl]

        def process
          # XEP-0078 says we MUST send a service-unavailable error
          # here, but Adium 1.4.1 won't login if we do that, so just
          # swallow this stanza.
          # raise StanzaErrors::ServiceUnavailable.new(@node, 'cancel')
        end
      end
    end
  end
end
