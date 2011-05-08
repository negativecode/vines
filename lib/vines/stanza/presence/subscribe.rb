# encoding: UTF-8

module Vines
  class Stanza
    class Presence
      class Subscribe < Presence
        register "/presence[@type='subscribe']"

        def process
          inbound? ? process_inbound : process_outbound
        end

        def process_outbound
          self['from'] = stream.user.jid.bare.to_s
          to = stamp_to
          route unless local?

          stream.user.request_subscription(to)
          storage.save_user(stream.user)
          stream.update_user_streams(stream.user)

          process_inbound if local?

          router.interested_resources(stream.user.jid).each do |recipient|
            send_subscribe_roster_push(recipient, stream.user.contact(to))
          end
        end

        def process_inbound
          self['from'] = stream.user.jid.bare.to_s
          to = stamp_to

          contact = storage(to.domain).find_user(to)
          if contact.nil?
            auto_reply_to_subscription_request(to, 'unsubscribed')
          elsif contact.subscribed_from?(stream.user.jid)
            auto_reply_to_subscription_request(to, 'subscribed')
          else
            recipients = router.available_resources(to)
            if recipients.empty?
              # TODO store subscription request per RFC 6121 3.1.3 #4
            else
              recipients.each {|stream| stream.write(@node) }
            end
          end
        end

        private

        def send_subscribe_roster_push(recipient, contact)
          doc = Document.new
          node = doc.create_element('iq') do |el|
            el['id'] = Kit.uuid
            el['to'] = recipient.user.jid.to_s
            el['type'] = 'set'
            el << doc.create_element('query') do |query|
              query.default_namespace = NAMESPACES[:roster]
              query << contact.to_roster_xml
            end
          end
          recipient.write(node)
        end
      end
    end
  end
end
