# encoding: UTF-8

module Vines
  class Stanza
    class Presence
      class Unsubscribe < Presence
        register "/presence[@type='unsubscribe']"

        def process
          inbound? ? process_inbound : process_outbound
        end

        def process_outbound
          self['from'] = stream.user.jid.bare.to_s
          to = stamp_to

          return unless stream.user.subscribed_to?(to)
          local? ? process_inbound : route

          stream.user.remove_subscription_to(to)
          storage.save_user(stream.user)
          stream.update_user_streams(stream.user)

          contact = stream.user.contact(to)
          stream.interested_resources(stream.user.jid).each do |recipient|
            contact.send_roster_push(recipient)
          end
        end

        def process_inbound
          self['from'] = stream.user.jid.bare.to_s
          to = stamp_to

          user = storage(to.domain).find_user(to)
          return unless user && user.subscribed_from?(stream.user.jid)
          contact = user.contact(stream.user.jid)
          contact.unsubscribe_from
          storage(to.domain).save_user(user)
          stream.update_user_streams(user)

          stream.interested_resources(to).each do |recipient|
            recipient.write(@node)
            contact.send_roster_push(recipient)
          end
          send_unavailable(to, stream.user.jid.bare)
        end
      end
    end
  end
end
