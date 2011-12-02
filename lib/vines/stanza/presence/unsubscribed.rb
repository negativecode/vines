# encoding: UTF-8

module Vines
  class Stanza
    class Presence
      class Unsubscribed < Presence
        register "/presence[@type='unsubscribed']"

        def process
          stamp_from
          inbound? ? process_inbound : process_outbound
        end

        def process_outbound
          to = stamp_to
          return unless stream.user.subscribed_from?(to)
          send_unavailable(stream.user.jid, to)
          stream.user.remove_subscription_from(to)
          storage.save_user(stream.user)
          stream.update_user_streams(stream.user)
          local? ? process_inbound : route
          send_roster_push(to)
        end

        def process_inbound
          to = stamp_to
          user = storage(to.domain).find_user(to)
          return unless user && user.subscribed_to?(stream.user.jid)
          contact = user.contact(stream.user.jid)
          contact.unsubscribe_to
          storage(to.domain).save_user(user)
          stream.update_user_streams(user)
          broadcast_subscription_change(contact)
        end
      end
    end
  end
end
