# encoding: UTF-8

module Vines
  class Stanza
    class PubSub
      class Unsubscribe < PubSub
        NS = NAMESPACES[:pubsub]

        register "/iq[@id and @type='set']/ns:pubsub/ns:unsubscribe", 'ns' => NS

        def process
          return if route_iq || !allowed?
          validate_to_address

          node = self.xpath('ns:pubsub/ns:unsubscribe', 'ns' => NS)
          raise StanzaErrors::BadRequest.new(self, 'modify') if node.size != 1
          node = node.first
          id, jid = node['node'], JID.new(node['jid'])

          raise StanzaErrors::Forbidden.new(self, 'auth') unless stream.user.jid.bare == jid.bare
          raise StanzaErrors::ItemNotFound.new(self, 'cancel') unless pubsub.node?(id)
          raise StanzaErrors::UnexpectedRequest.new(self, 'cancel') unless pubsub.subscribed?(id, jid)

          pubsub.unsubscribe(id, jid)
          stream.write(to_result)
        end
      end
    end
  end
end
