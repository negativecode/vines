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

          stream.user.add_subscription_from(to)
          storage.save_user(stream.user)
          stream.update_user_streams(stream.user)

          local? ? process_inbound : route

          contact = stream.user.contact(to)
          stream.interested_resources(stream.user.jid).each do |recipient|
            contact.send_roster_push(recipient)
          end

          presences = stream.available_resources(stream.user.jid).map do |c|
            c.last_broadcast_presence.clone.tap do |node|
              node['from'] = c.user.jid.to_s
              node['id'] = Kit.uuid
              node['to'] = to.to_s
            end
          end

          if local?
            stream.available_resources(to).each do |recipient|
              presences.each {|el| recipient.write(el) }
            end
          else
            presences.each {|el| router.route(el) }
          end
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

          stream.interested_resources(to).each do |recipient|
            recipient.write(@node)
            contact.send_roster_push(recipient)
          end
        end
      end
    end
  end
end
