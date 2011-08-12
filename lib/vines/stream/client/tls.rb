# encoding: UTF-8

module Vines
  class Stream
    class Client
      class TLS < State
        NS = NAMESPACES[:tls]
        PROCEED  = %Q{<proceed xmlns="#{NS}"/>}.freeze
        FAILURE  = %Q{<failure xmlns="#{NS}"/>}.freeze
        STARTTLS = 'starttls'.freeze

        def initialize(stream, success=AuthRestart)
          super
        end

        def node(node)
          raise StreamErrors::NotAuthorized unless starttls?(node)
          if stream.encrypt?
            stream.write(PROCEED)
            stream.encrypt
            stream.reset
            advance
          else
            stream.write(FAILURE)
            stream.write('</stream:stream>')
            stream.close_connection_after_writing
          end
        end

        private

        def starttls?(node)
          node.name == STARTTLS && namespace(node) == NS
        end
      end
    end
  end
end
