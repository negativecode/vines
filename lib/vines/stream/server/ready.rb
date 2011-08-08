# encoding: UTF-8

module Vines
  class Stream
    class Server
      class Ready < State
        def node(node)
          stanza = to_stanza(node)
          raise StreamErrors::UnsupportedStanzaType unless stanza
          to, from = stanza.validate_to, stanza.validate_from
          raise StreamErrors::ImproperAddressing unless to && from
          raise StreamErrors::InvalidFrom unless from.domain == stream.remote_domain
          raise StreamErrors::HostUnknown unless to.domain == stream.domain
          stream.user = User.new(:jid => from)
          stanza.process
        end
      end
    end
  end
end
