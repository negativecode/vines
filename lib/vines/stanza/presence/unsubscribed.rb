# encoding: UTF-8

module Vines
  class Stanza
    class Presence
      class Unsubscribed < Presence
        register "/presence[@type='unsubscribed']"

        def process
          inbound? ? process_inbound : process_outbound
        end

        def process_outbound
          self['from'] = stream.user.jid.bare.to_s
          to = stamp_to

          return unless stream.user.subscribed_from?(to)
          send_unavailable(stream.user.jid, to)

          stream.user.remove_subscription_from(to)
          storage.save_user(stream.user)
          stream.update_user_streams(stream.user)

          local? ? process_inbound : route

          contact = stream.user.contact(to)
          stream.interested_resources(stream.user.jid).each do |recipient|
            contact.send_roster_push(recipient)
          end
        end

        def process_inbound
          self['from'] = stream.user.jid.bare.to_s
          to = stamp_to

          user = storage(to.domain).find_user(to)
          return unless user && user.subscribed_to?(stream.user.jid)
          contact = user.contact(stream.user.jid)
          contact.unsubscribe_to
          storage(to.domain).save_user(user)
          stream.update_user_streams(user)

          stream.interested_resources(to).each do |recipient|
            recipient.write(@node)
            contact.send_roster_push(recipient)
          end
        end
      end
    end
  end
end
