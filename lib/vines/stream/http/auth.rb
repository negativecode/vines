# encoding: UTF-8

module Vines
  class Stream
    class Http
      class Auth < Client::Auth
        def initialize(stream, success=BindRestart)
          super
        end

        def node(node)
          unless body?(node) && node['rid'] && stream.valid_session?(node['sid'])
            raise StreamErrors::NotAuthorized
          end
          nodes = stream.parse_body(node)
          raise StreamErrors::NotAuthorized unless nodes.size == 1
          super(nodes.first)
        end
      end
    end
  end
end
