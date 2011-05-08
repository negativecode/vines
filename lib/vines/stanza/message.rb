# encoding: UTF-8

module Vines
  class Stanza
    class Message < Stanza
      register "/message"

      TYPE, TO, FROM = %w[type to from].map {|s| s.freeze }
      VALID_TYPES    = %w[chat error groupchat headline normal].freeze

      VALID_TYPES.each do |type|
        define_method "#{type}?" do
          self[TYPE] == type
        end
      end

      def process
        unless self[TYPE].nil? || VALID_TYPES.include?(self[TYPE])
          raise StanzaErrors::BadRequest.new(self, 'modify')
        end

        if local?
          to = (self[TO] || '').strip
          to = to.empty? ? stream.user.jid.bare : JID.new(to)
          recipients = router.connected_resources(to)
          if recipients.empty?
            if user = storage(to.domain).find_user(to)
              # TODO Implement offline messaging storage
              raise StanzaErrors::ServiceUnavailable.new(self, 'cancel')
            end
          else
            broadcast(recipients)
          end
        else
          self[FROM] = stream.user.jid.to_s
          route
        end
      end
    end
  end
end
