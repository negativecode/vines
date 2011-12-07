# encoding: UTF-8

module Vines
  class Stanza
    class Iq
      class Vcard < Iq
        NS = NAMESPACES[:vcard]

        register "/iq[@id and @type='get' or @type='set']/ns:vCard", 'ns' => NS

        def process
          return unless allowed?
          if local?
            get? ? vcard_query : vcard_update
          else
            self['from'] = stream.user.jid.to_s
            route
          end
        end

        private

        def vcard_query
          to = validate_to
          jid = to ? to.bare : stream.user.jid.bare
          card = storage(jid.domain).find_vcard(jid)

          raise StanzaErrors::ItemNotFound.new(self, 'cancel') unless card

          doc = Document.new
          result = doc.create_element('iq') do |node|
            node['from'] = jid.to_s unless jid == stream.user.jid.bare
            node['id']   = self['id']
            node['to']   = stream.user.jid.to_s
            node['type'] = 'result'
            node << card
          end
          stream.write(result)
        end

        def vcard_update
          to = validate_to
          unless to.nil? || to == stream.user.jid.bare
            raise StanzaErrors::Forbidden.new(self, 'auth')
          end

          storage.save_vcard(stream.user.jid, elements.first)

          result = to_result
          result.remove_attribute('from')
          stream.write(result)
        end
      end
    end
  end
end
