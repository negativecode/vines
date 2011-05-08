# encoding: UTF-8

module Vines
  class Stream
    class Server
      class Ready < State
        def node(node)
          stanza = to_stanza(node)
          raise StreamErrors::UnsupportedStanzaType unless stanza
          to, from = %w[to from].map {|attr| JID.new(stanza[attr] || '') }
          raise StreamErrors::ImproperAddressing if [to, from].any? {|addr| (addr.domain || '').strip.empty? }
          raise StreamErrors::InvalidFrom unless from.domain == stream.remote_domain
          raise StreamErrors::HostUnknown unless to.domain == stream.domain
          stream.user = User.new(:jid => from)
          stanza.process
        end
      end
    end
  end
end
