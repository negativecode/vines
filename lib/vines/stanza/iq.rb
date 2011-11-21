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
          'from' => stream.domain,
          'id'   => self['id'],
          'to'   => stream.user.jid.to_s,
          'type' => 'result')
      end

      private

      def route_iq
        to = validate_to
        return false if to.nil? || to.to_s == stream.domain
        self['from'] = stream.user.jid.to_s
        local? ? broadcast(stream.available_resources(to)) : route
        true
      end
    end
  end
end
