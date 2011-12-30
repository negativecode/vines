# encoding: UTF-8

module Vines
  class Stanza
    class Iq < Stanza
      register "/iq"

      VALID_TYPES = %w[get set result error].freeze

      VALID_TYPES.each do |type|
        define_method "#{type}?" do
          self['type'] == type
        end
      end

      def process
        if self['id'] && VALID_TYPES.include?(self['type'])
          route_iq or raise StanzaErrors::FeatureNotImplemented.new(@node, 'cancel')
        else
          raise StanzaErrors::BadRequest.new(@node, 'modify')
        end
      end

      def to_result
        doc = Document.new
        doc.create_element('iq',
          'from' => validate_to || stream.domain,
          'id'   => self['id'],
          'to'   => stream.user.jid,
          'type' => 'result')
      end

      private

      # Return false if this IQ stanza is addressed to the server, or a pubsub
      # service hosted here, and must be handled locally. Return true if the
      # stanza must not be handled locally and has been routed to the appropriate
      # component, s2s, or c2s stream.
      def route_iq
        to = validate_to
        return false if to.nil? || stream.config.vhost?(to) || to_pubsub_domain?
        self['from'] = stream.user.jid.to_s
        local? ? broadcast(stream.connected_resources(to)) : route
        true
      end
    end
  end
end
