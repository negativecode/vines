# encoding: UTF-8

module Vines
  class Stream
    class Http
      class Bind < Client::Bind
        FEATURES = %Q{<stream:features xmlns:stream="#{NAMESPACES[:stream]}"/>}.freeze

        def initialize(stream, success=Ready)
          super
        end

        def node(node)
          unless stream.valid_session?(node['sid']) && body?(node) && node['rid']
            raise StreamErrors::NotAuthorized
          end
          nodes = stream.parse_body(node)
          raise StreamErrors::NotAuthorized unless nodes.size == 1
          super(nodes.first)
        end

        private

        # Override Client::Bind#send_empty_features to properly namespace the
        # empty features element.
        def send_empty_features
          stream.write(FEATURES)
        end
      end
    end
  end
end
