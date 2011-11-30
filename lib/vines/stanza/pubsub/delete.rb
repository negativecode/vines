# encoding: UTF-8

module Vines
  class Stanza
    class PubSub
      class Delete < PubSub
        NS = NAMESPACES[:pubsub]

        register "/iq[@id and @type='set']/ns:pubsub/ns:delete", 'ns' => NS

        def process
          return if route_iq || !allowed?
          validate_to_address

          node = self.xpath('ns:pubsub/ns:delete', 'ns' => NS)
          raise StanzaErrors::BadRequest.new(self, 'modify') if node.size != 1
          node = node.first

          id = node['node']
          raise StanzaErrors::ItemNotFound.new(self, 'cancel') unless pubsub.node?(id)

          pubsub.publish(id, message(id))
          pubsub.delete_node(id)
          stream.write(to_result)
        end

        private

        def message(id)
          doc = Document.new
          doc.create_element('message') do |node|
            node << node.document.create_element('event') do |event|
              event.default_namespace = NAMESPACES[:pubsub_event]
              event << node.document.create_element('delete', 'node' => id)
            end
          end
        end
      end
    end
  end
end
