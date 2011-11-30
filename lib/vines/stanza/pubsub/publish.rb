# encoding: UTF-8

module Vines
  class Stanza
    class PubSub
      class Publish < PubSub
        NS = NAMESPACES[:pubsub]

        register "/iq[@id and @type='set']/ns:pubsub/ns:publish", 'ns' => NS

        def process
          return if route_iq || !allowed?
          validate_to_address

          node = self.xpath('ns:pubsub/ns:publish', 'ns' => NS)
          raise StanzaErrors::BadRequest.new(self, 'modify') if node.size != 1
          node = node.first
          id = node['node']

          raise StanzaErrors::ItemNotFound.new(self, 'cancel') unless pubsub.node?(id)

          item = node.xpath('ns:item', 'ns' => NS)
          raise StanzaErrors::BadRequest.new(self, 'modify') unless item.size == 1
          item = item.first
          unless item['id']
            item['id'] = Kit.uuid
            include_item = true
          end

          raise StanzaErrors::BadRequest.new(self, 'modify') unless item.elements.size == 1
          pubsub.publish(id, message(id, item))
          send_result_iq(id, include_item ? item : nil)
        end

        private

        def message(node, item)
          doc = Document.new
          doc.create_element('message') do |message|
            message << doc.create_element('event') do |event|
              event.default_namespace = NAMESPACES[:pubsub_event]
              event << doc.create_element('items', 'node' => node) do |items|
                items << doc.create_element('item', 'id' => item['id'], 'publisher' => stream.user.jid.to_s) do |el|
                  el << item.elements.first
                end
              end
            end
          end
        end

        def send_result_iq(node, item)
          result = to_result
          if item
            result << result.document.create_element('pubsub') do |pubsub|
              pubsub.default_namespace = NS
              pubsub << result.document.create_element('publish', 'node' => node) do |publish|
                publish << result.document.create_element('item', 'id' => item['id'])
              end
            end
          end
          stream.write(result)
        end
      end
    end
  end
end
