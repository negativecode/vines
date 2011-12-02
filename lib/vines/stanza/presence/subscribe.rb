# encoding: UTF-8

module Vines
  class Stanza
    class Presence
      class Subscribe < Presence
        register "/presence[@type='subscribe']"

        def process
          stamp_from
          inbound? ? process_inbound : process_outbound
        end

        def process_outbound
          to = stamp_to
          stream.user.request_subscription(to)
          storage.save_user(stream.user)
          stream.update_user_streams(stream.user)
          local? ? process_inbound : route
          send_roster_push(to)
        end

        def process_inbound
          to = stamp_to
          contact = storage(to.domain).find_user(to)
          if contact.nil?
            auto_reply_to_subscription_request(to, 'unsubscribed')
          elsif contact.subscribed_from?(stream.user.jid)
            auto_reply_to_subscription_request(to, 'subscribed')
          else
            recipients = stream.available_resources(to)
            if recipients.empty?
              # TODO store subscription request per RFC 6121 3.1.3 #4
            else
              broadcast_to_available_resources([@node], to)
            end
          end
        end
      end
    end
  end
end
