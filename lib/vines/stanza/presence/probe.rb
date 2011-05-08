# encoding: UTF-8

module Vines
  class Stanza
    class Presence
      class Probe < Presence
        register "/presence[@type='probe']"

        def process
          inbound? ? process_inbound : process_outbound
        end

        def process_outbound
          self['from'] = stream.user.jid.to_s
          local? ? process_inbound : route
        end

        def process_inbound
          to = (self['to'] || '').strip
          raise StanzaErrors::BadRequest.new(self, 'modify') if to.empty?
          to = JID.new(to)

          user = storage(to.domain).find_user(to)
          unless user && user.subscribed_from?(stream.user.jid)
            auto_reply_to_subscription_request(to.bare, 'unsubscribed')
          else
            router.available_resources(to).each do |recipient|
              el = recipient.last_broadcast_presence.clone
              el['from'] = recipient.user.jid.to_s
              el['to'] = stream.user.jid.to_s
              stream.write(el)
            end
          end
        end
      end
    end
  end
end
