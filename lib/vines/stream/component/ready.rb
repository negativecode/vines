# encoding: UTF-8

module Vines
  class Stream
    class Component
      class Ready < State
        def node(node)
          stanza = to_stanza(node)
          raise StreamErrors::UnsupportedStanzaType unless stanza
          to = (node['to'] || '').strip
          from = JID.new(node['from'] || '')
          raise StreamErrors::ImproperAddressing if to.empty? || from.domain != stream.remote_domain
          if stanza.local?
            stream.router.connected_resources(to, from).each do |recipient|
              recipient.write(node)
            end
          else
            stanza.route
          end
        end
      end
    end
  end
end
