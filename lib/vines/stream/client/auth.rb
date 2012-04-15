# encoding: UTF-8

module Vines
  class Stream
    class Client
      class Auth < State
        NS        = NAMESPACES[:sasl]
        MECHANISM = 'mechanism'.freeze
        AUTH      = 'auth'.freeze
        PLAIN     = 'PLAIN'.freeze
        EXTERNAL  = 'EXTERNAL'.freeze
        SUCCESS   = %Q{<success xmlns="#{NS}"/>}.freeze
        MAX_AUTH_ATTEMPTS = 3

        def initialize(stream, success=BindRestart)
          super
          @attempts = 0
          @sasl = SASL.new(stream)
        end

        def node(node)
          raise StreamErrors::NotAuthorized unless auth?(node)
          if node.text.empty?
            send_auth_fail(SaslErrors::MalformedRequest.new)
          elsif stream.authentication_mechanisms.include?(node[MECHANISM])
            case node[MECHANISM]
            when PLAIN    then plain_auth(node)
            when EXTERNAL then external_auth(node)
            end
          else
            send_auth_fail(SaslErrors::InvalidMechanism.new)
          end
        end

        private

        def auth?(node)
          node.name == AUTH && namespace(node) == NS
        end

        def plain_auth(node)
          stream.user = @sasl.plain_auth(node.text)
          send_auth_success
        rescue => e
          send_auth_fail(e)
        end

        def external_auth(node)
          @sasl.external_auth(node.text)
          send_auth_success
        rescue => e
          send_auth_fail(e)
          stream.write('</stream:stream>')
          stream.close_connection_after_writing
        end

        def send_auth_success
          stream.write(SUCCESS)
          stream.reset
          advance
        end

        def send_auth_fail(condition)
          @attempts += 1
          if @attempts >= MAX_AUTH_ATTEMPTS
            stream.error(StreamErrors::PolicyViolation.new("max authentication attempts exceeded"))
          else
            stream.error(condition)
          end
        end
      end
    end
  end
end
