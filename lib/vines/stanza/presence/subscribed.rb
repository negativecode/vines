# encoding: UTF-8

module Vines
  class Stanza
    class Presence
      class Subscribed < Presence
        register "/presence[@type='subscribed']"

        def process
          stamp_from
          inbound? ? process_inbound : process_outbound
        end

        def process_outbound
          to = stamp_to
          stream.user.add_subscription_from(to)
          storage.save_user(stream.user)
          stream.update_user_streams(stream.user)
          local? ? process_inbound : route
          send_roster_push(to)
          send_known_presence(to)
        end

        def process_inbound
          to = stamp_to
          user = storage(to.domain).find_user(to)
          contact = user.contact(stream.user.jid) if user
          return unless contact && contact.can_subscribe?
          contact.subscribe_to
          storage(to.domain).save_user(user)
          stream.update_user_streams(user)
          broadcast_subscription_change(contact)
        end

        private

        # After approving a contact's subscription to this user's presence,
        # broadcast this user's most recent presence stanzas to the contact.
        def send_known_presence(to)
          stanzas = stream.available_resources(stream.user.jid).map do |stream|
            stream.last_broadcast_presence.clone.tap do |node|
              node['from'] = stream.user.jid.to_s
              node['id'] = Kit.uuid
            end
          end
          broadcast_to_available_resources(stanzas, to)
        end
      end
    end
  end
end
