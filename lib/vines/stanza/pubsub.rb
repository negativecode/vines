# encoding: UTF-8

module Vines
  class Stanza
    class PubSub < Iq

      private

      # Return the Config::PubSub system for the domain to which this stanza is
      # addressed or nil if it's not to a pubsub subdomain.
      def pubsub
        stream.config.pubsub(validate_to)
      end

      # Raise feature-not-implemented if this stanza is addressed to the chat
      # server itself, rather than a pubsub subdomain.
      def validate_to_address
        raise StanzaErrors::FeatureNotImplemented.new(self, 'cancel') unless pubsub
      end
    end
  end
end
