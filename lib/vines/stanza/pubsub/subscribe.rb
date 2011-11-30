# encoding: UTF-8

module Vines
  class Stanza
    class PubSub
      class Subscribe < PubSub
        NS = NAMESPACES[:pubsub]

        register "/iq[@id and @type='set']/ns:pubsub/ns:subscribe", 'ns' => NS

        def process
          return if route_iq || !allowed?
          validate_to_address

          node = self.xpath('ns:pubsub/ns:subscribe', 'ns' => NS)
          raise StanzaErrors::BadRequest.new(self, 'modify') if node.size != 1
          node = node.first
          id, jid = node['node'], JID.new(node['jid'])

          raise StanzaErrors::BadRequest.new(self, 'modify') unless stream.user.jid.bare == jid.bare
          raise StanzaErrors::ItemNotFound.new(self, 'cancel') unless pubsub.node?(id)
          raise StanzaErrors::PolicyViolation.new(self, 'wait') if pubsub.subscribed?(id, jid)

          pubsub.subscribe(id, jid)
          send_result_iq(id, jid)
        end

        private

        def send_result_iq(id, jid)
          result = to_result
          result << result.document.create_element('pubsub') do |node|
            node.default_namespace = NS
            node << result.document.create_element('subscription',
              'node' => id,
              'jid' => jid.to_s,
              'subscription' => 'subscribed')
          end
          stream.write(result)
        end
      end
    end
  end
end
