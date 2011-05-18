# encoding: UTF-8

module Vines
  class Stream
    class Http
      class Ready < Client::Ready
        RID, SID, TYPE, TERMINATE = %w[rid sid type terminate].map {|s| s.freeze }

        def node(node)
          unless body?(node) && node[RID] && stream.valid_session?(node[SID])
            raise StreamErrors::NotAuthorized
          end
          stream.parse_body(node).each do |child|
            super(child)
          end
          stream.terminate if terminate?(node)
        end

        def terminate?(node)
          node[TYPE] == TERMINATE
        end
      end
    end
  end
end
