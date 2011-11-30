# encoding: UTF-8

module Vines
  class Stanza
    class PubSub
      class Create < PubSub
        NS = NAMESPACES[:pubsub]

        register "/iq[@id and @type='set']/ns:pubsub/ns:create", 'ns' => NS

        def process
          return if route_iq || !allowed?
          validate_to_address

          node = self.xpath('ns:pubsub/ns:create', 'ns' => NS)
          raise StanzaErrors::BadRequest.new(self, 'modify') if node.size != 1
          node = node.first

          id = (node['node'] || '').strip
          id = Kit.uuid if id.empty?
          raise StanzaErrors::Conflict.new(self, 'cancel') if pubsub.node?(id)
          pubsub.add_node(id)
          send_result_iq(id)
        end

        private

        def send_result_iq(id)
          el = to_result
          el << el.document.create_element('pubsub') do |node|
            node.default_namespace = NS
            node << el.document.create_element('create', 'node' => id)
          end
          stream.write(el)
        end
      end
    end
  end
end
