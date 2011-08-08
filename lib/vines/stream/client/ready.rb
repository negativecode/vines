# encoding: UTF-8

module Vines
  class Stream
    class Client
      class Ready < State
        def node(node)
          stanza = to_stanza(node)
          raise StreamErrors::UnsupportedStanzaType unless stanza
          stanza.validate_to
          stanza.validate_from
          stanza.process
        end
      end
    end
  end
end
