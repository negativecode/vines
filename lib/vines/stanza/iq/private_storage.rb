# encoding: UTF-8

module Vines
  class Stanza
    class Iq
      # Implements the Private Storage feature defined in XEP-0049. Clients are
      # allowed to save arbitrary XML documents on the server, identified by
      # element name and namespace.
      class PrivateStorage < Query
        NS = NAMESPACES[:storage]

        register "/iq[@id and (@type='get' or @type='set')]/ns:query", 'ns' => NS

        def process
          validate_to_address
          validate_children_size
          validate_namespaces
          get? ? retrieve_fragment : update_fragment
        end

        private

        def retrieve_fragment
          found = storage.find_fragment(stream.user.jid, elements.first.elements.first)
          raise StanzaErrors::ItemNotFound.new(self, 'cancel') unless found

          result = to_result do |node|
            node << node.document.create_element('query') do |query|
              query.default_namespace = NS
              query << found
            end
          end
          stream.write(result)
        end

        def update_fragment
          elements.first.elements.each do |node|
            storage.save_fragment(stream.user.jid, node)
          end
          stream.write(to_result)
        end

        private

        def to_result
          doc = Document.new
          node = doc.create_element('iq',
            'from' => stream.user.jid.to_s,
            'id'   => self['id'],
            'to'   => stream.user.jid.to_s,
            'type' => 'result')
          yield node if block_given?
          node
        end

        def validate_children_size
          size = elements.first.elements.size
          if (get? && size != 1) || (set? && size == 0)
            raise StanzaErrors::NotAcceptable.new(self, 'modify')
          end
        end

        def validate_to_address
          to = (self['to'] || '').strip
          unless to.empty? || to == stream.user.jid.bare.to_s
            raise StanzaErrors::Forbidden.new(self, 'cancel')
          end
        end

        def validate_namespaces
          elements.first.elements.each do |node|
            if node.namespace.nil? || NAMESPACES.values.include?(node.namespace.href)
              raise StanzaErrors::NotAcceptable.new(self, 'modify')
            end
          end
        end
      end
    end
  end
end
