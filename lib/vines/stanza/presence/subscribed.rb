# encoding: UTF-8

module Vines
  class Stanza
    class Presence
      class Subscribed < Presence
        register "/presence[@type='subscribed']"

        def process
          inbound? ? process_inbound : process_outbound
        end

        def process_outbound
          self['from'] = stream.user.jid.bare.to_s
          to = stamp_to
          route unless local?

          stream.user.add_subscription_from(to)
          storage.save_user(stream.user)
          stream.update_user_streams(stream.user)

          router.interested_resources(stream.user.jid).each do |recipient|
            send_subscribed_roster_push(recipient, to, stream.user.contact(to).subscription)
          end

          presences = router.available_resources(stream.user.jid).map do |c|
            doc = Document.new
            doc.create_element('presence',
              'from' => c.user.jid.to_s,
              'id'   => Kit.uuid,
              'to'   => to.to_s)
          end

          if local?
            router.available_resources(to).each do |recipient|
              presences.each {|el| recipient.write(el) }
            end
          else
            presences.each {|el| router.route(el) }
          end

          process_inbound if local?
        end

        def process_inbound
          self['from'] = stream.user.jid.bare.to_s
          to = stamp_to

          user = storage(to.domain).find_user(to)
          contact = user.contact(stream.user.jid) if user
          return unless contact && contact.can_subscribe?
          contact.subscribe_to
          storage(to.domain).save_user(user)
          stream.update_user_streams(user)

          router.interested_resources(to).each do |recipient|
            recipient.write(@node)
            send_subscribed_roster_push(recipient, stream.user.jid.bare, contact.subscription)
          end
        end
      end
    end
  end
end
