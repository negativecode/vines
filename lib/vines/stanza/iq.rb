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
        to = (self['to'] || '').strip
        return false if to.empty? || to == stream.domain
        self['from'] = stream.user.jid.to_s
        if local?
          stream.available_resources(to).each do |recipient|
            recipient.write(@node)
          end
        else
          route
        end
        true
      end
    end
  end
end
