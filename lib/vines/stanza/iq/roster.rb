# encoding: UTF-8

module Vines
  class Stanza
    class Iq
      class Roster < Query
        NS = NAMESPACES[:roster]

        register "/iq[@id and (@type='get' or @type='set')]/ns:query", 'ns' => NS

        def process
          get? ? roster_query : update_roster
        end

        private

        # Send an iq result stanza containing roster items to the user in
        # response to their roster get request. Requesting the roster makes
        # this stream an "interested resource" that can now receive roster
        # updates.
        def roster_query
          stream.requested_roster!
          stream.write(stream.user.to_roster_xml(self['id']))
        end

        # Roster sets must have no 'to' address or be addressed to the same
        # JID that sent the stanza. RFC 6121 sections 2.1.5 and 2.3.3.
        def validate_to_address
          to = validate_to
          unless to.nil? || to.bare == stream.user.jid.bare
            raise StanzaErrors::Forbidden.new(self, 'auth')
          end
        end

        # Add, update, or delete the roster item contained in the iq set
        # stanza received from the client. RFC 6121 sections 2.3, 2.4, 2.5.
        def update_roster
          validate_to_address

          items = self.xpath('ns:query/ns:item', 'ns' => NS)
          raise StanzaErrors::BadRequest.new(self, 'modify') if items.size != 1
          item = items.first

          jid = JID.new(item['jid'])
          raise StanzaErrors::BadRequest.new(self, 'modify') if jid.empty? || !jid.bare?

          if item['subscription'] == 'remove'
            remove_contact(jid)
            return
          end

          raise StanzaErrors::NotAllowed.new(self, 'modify') if jid == stream.user.jid.bare
          groups = item.xpath('ns:group', 'ns' => NS).map {|g| g.text.strip }
          raise StanzaErrors::BadRequest.new(self, 'modify') if groups.uniq!
          raise StanzaErrors::NotAcceptable.new(self, 'modify') if groups.include?('')

          contact = stream.user.contact(jid)
          unless contact
            contact = Contact.new(:jid => jid)
            stream.user.roster << contact
          end
          contact.name = item['name']
          contact.groups = groups
          storage.save_user(stream.user)
          stream.update_user_streams(stream.user)
          send_result_iq
          push_roster_updates(stream.user.jid, contact)
        end

        # Remove the contact with this JID from the user's roster and send
        # roster pushes to the user's interested resources. This is triggered
        # by receiving an iq set with an item element like
        # <item jid="alice@wonderland.lit" subscription="remove"/>. RFC 6121
        # section 2.5.
        def remove_contact(jid)
          contact = stream.user.contact(jid)
          raise StanzaErrors::ItemNotFound.new(self, 'modify') unless contact
          if router.local_jid?(contact.jid)
            user = storage(contact.jid.domain).find_user(contact.jid)
          end

          if user && user.contact(stream.user.jid)
            user.contact(stream.user.jid).subscription = 'none'
            user.contact(stream.user.jid).ask = nil
          end
          stream.user.remove_contact(contact.jid)
          [user, stream.user].compact.each do |save|
            storage(save.jid.domain).save_user(save)
            stream.update_user_streams(save)
          end

          send_result_iq
          push_roster_updates(stream.user.jid, Contact.new(
            :jid => contact.jid,
            :subscription => 'remove'))

          if router.local_jid?(contact.jid)
            send_unavailable(stream.user.jid, contact.jid) if contact.subscribed_from?
            send_unsubscribe(contact)
            if user.contact(stream.user.jid)
              push_roster_updates(contact.jid, user.contact(stream.user.jid))
            end
          else
            send_unsubscribe(contact)
          end
        end

        # Notify the contact that it's been removed from the user's roster
        # and no longer has any presence relationship with the user.
        def send_unsubscribe(contact)
          presence = [%w[to unsubscribe], %w[from unsubscribed]].map do |meth, type|
            presence(contact.jid, type) if contact.send("subscribed_#{meth}?")
          end.compact

          if router.local_jid?(contact.jid)
            stream.interested_resources(contact.jid).each do |recipient|
              presence.each {|el| recipient.write(el) }
            end
          else
            presence.each {|el| router.route(el) }
          end
        end

        def presence(to, type)
          doc = Document.new
          doc.create_element('presence',
            'from' => stream.user.jid.bare.to_s,
            'id'   => Kit.uuid,
            'to'   => to.to_s,
            'type' => type)
        end

        # Send an iq set stanza to the user's interested resources, letting them
        # know their roster has been updated.
        def push_roster_updates(to, contact)
          stream.interested_resources(to).each do |recipient|
            contact.send_roster_push(recipient)
          end
        end

        def send_result_iq
          doc = Document.new
          node = doc.create_element('iq', 'id' => self['id'], 'type' => 'result')
          stream.write(node)
        end
      end
    end
  end
end
