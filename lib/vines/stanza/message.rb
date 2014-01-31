# encoding: UTF-8

module Vines
  class Stanza
    class Message < Stanza
      register "/message"

      TYPE, FROM  = %w[type from].map {|s| s.freeze }
      VALID_TYPES = %w[chat error groupchat headline normal].freeze

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
          to = validate_to || stream.user.jid.bare
          recipients = stream.connected_resources(to)
          if recipients.empty?
            if user = storage(to.domain).find_user(to)
              raise StanzaErrors::ServiceUnavailable.new(self, 'cancel')
              self[FROM] = stream.user.jid.to_s
              unless self.css('body').inner_text == ''
                storage(to.domain).delay_message(to, self)
              end
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
