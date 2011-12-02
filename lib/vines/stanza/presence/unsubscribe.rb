# encoding: UTF-8

module Vines
  class Stanza
    class Presence
      class Unsubscribe < Presence
        register "/presence[@type='unsubscribe']"

        def process
          stamp_from
          inbound? ? process_inbound : process_outbound
        end

        def process_outbound
          to = stamp_to
          return unless stream.user.subscribed_to?(to)
          stream.user.remove_subscription_to(to)
          storage.save_user(stream.user)
          stream.update_user_streams(stream.user)
          local? ? process_inbound : route
          send_roster_push(to)
        end

        def process_inbound
          to = stamp_to
          user = storage(to.domain).find_user(to)
          return unless user && user.subscribed_from?(stream.user.jid)
          contact = user.contact(stream.user.jid)
          contact.unsubscribe_from
          storage(to.domain).save_user(user)
          stream.update_user_streams(user)
          broadcast_subscription_change(contact)
          send_unavailable(to, stream.user.jid.bare)
        end
      end
    end
  end
end
