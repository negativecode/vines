# encoding: UTF-8

module Vines
  class Stanza
    class Presence < Stanza
      register "/presence"

      VALID_TYPES = %w[subscribe subscribed unsubscribe unsubscribed unavailable probe error].freeze

      VALID_TYPES.each do |type|
        define_method "#{type}?" do
          self['type'] == type
        end
      end

      def process
        stream.last_broadcast_presence = @node.clone unless validate_to
        unless self['type'].nil?
          raise StanzaErrors::BadRequest.new(self, 'modify')
        end
        dir = outbound? ? 'outbound' : 'inbound'
        method("#{dir}_broadcast_presence").call
      end

      def outbound?
        stream.class != Vines::Stream::Server
      end

      def inbound?
        stream.class == Vines::Stream::Server
      end

      def outbound_broadcast_presence
        self['from'] = stream.user.jid.to_s
        to = validate_to
        type = (self['type'] || '').strip
        initial = to.nil? && type.empty? && !stream.available?

        recipients = if to.nil?
          stream.available_subscribers
        else
          stream.user.subscribed_from?(to) ? stream.available_resources(to) : []
        end

        broadcast(recipients)
        broadcast(stream.available_resources(stream.user.jid))

        if initial
          stream.available_subscribed_to_resources.each do |recipient|
            if recipient.last_broadcast_presence
              el = recipient.last_broadcast_presence.clone
              el['to'] = stream.user.jid.to_s
              el['from'] = recipient.user.jid.to_s
              stream.write(el)
            end
          end
          stream.available!
        end

        stream.remote_subscribers(to).each do |contact|
          node = @node.clone
          node['to'] = contact.jid.bare.to_s
          router.route(node) rescue nil # ignore RemoteServerNotFound
          send_probe(contact.jid.bare) if initial
        end
      end

      def inbound_broadcast_presence
        broadcast(stream.available_resources(validate_to))
      end

      private

      def send_probe(to)
        to = JID.new(to)
        doc = Document.new
        probe = doc.create_element('presence',
          'from' => stream.user.jid.bare.to_s,
          'id'   => Kit.uuid,
          'to'   => to.bare.to_s,
          'type' => 'probe')
        router.route(probe)
      end

      def auto_reply_to_subscription_request(from, type)
        doc = Document.new
        node = doc.create_element('presence') do |el|
          el['from'] = from.to_s
          el['id'] = self['id'] if self['id']
          el['to'] = stream.user.jid.bare.to_s
          el['type'] = type
        end
        stream.write(node)
      end

      # Validate that the incoming stanza has a 'to' attribute and strip any
      # resource part from it so it's a bare jid. Return the bare JID object
      # that was stamped.
      def stamp_to
        to = validate_to
        raise StanzaErrors::BadRequest.new(self, 'modify') unless to
        to.bare.tap do |bare|
          self['to'] = bare.to_s
        end
      end
    end
  end
end
