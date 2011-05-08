# encoding: UTF-8

module Vines
  class Stanza
    class Iq
      # Session support is deprecated, but Adium requires it so reply with an
      # iq result stanza.
      class Session < Iq
        register "/iq[@id and @type='set']/ns:session", 'ns' => NAMESPACES[:session]

        def process
          doc = Document.new
          result = doc.create_element('iq',
            'from' => stream.domain,
            'id'   => self['id'],
            'type' => 'result')
          stream.write(result)
        end
      end
    end
  end
end
