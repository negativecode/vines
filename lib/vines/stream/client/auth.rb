# encoding: UTF-8

module Vines
  class Stream
    class Client
      class Auth < State
        NS = NAMESPACES[:sasl]
        AUTH = 'auth'.freeze
        SUCCESS = %Q{<success xmlns="#{NS}"/>}.freeze
        MAX_AUTH_ATTEMPTS = 3
        AUTH_MECHANISMS = {'PLAIN' => :plain_auth, 'EXTERNAL' => :external_auth}.freeze
  
        def initialize(stream, success=BindRestart)
          super
          @attempts, @outstanding = 0, false
        end

        def node(node)
          raise StreamErrors::NotAuthorized unless auth?(node)
          unless node.text.empty?
            (name = AUTH_MECHANISMS[node['mechanism']]) ?
                method(name).call(node) :
                send_auth_fail(SaslErrors::InvalidMechanism.new)
          else
            send_auth_fail(SaslErrors::MalformedRequest.new)
          end
        end

        private

        def auth?(node)
          node.name == AUTH && namespace(node) == NS && !@outstanding
        end

        # Authenticate s2s streams by comparing their domain to
        # their SSL certificate.
        def external_auth(stanza)
          domain = Base64.decode64(stanza.text)
          cert = OpenSSL::X509::Certificate.new(stream.get_peer_cert) rescue nil
          if (!OpenSSL::SSL.verify_certificate_identity(cert, domain) rescue false)
            send_auth_fail(SaslErrors::NotAuthorized.new)
            stream.write('</stream:stream>')
            stream.close_connection_after_writing
          else
            stream.remote_domain = domain
            send_auth_success
          end
        end

        # Authenticate c2s streams using a username and password. Call the
        # authentication module in a separate thread to avoid blocking stanza
        # processing for other users. 
        def plain_auth(stanza)
          jid, node, password = Base64.decode64(stanza.text).split("\000")
          jid = [node, stream.domain].join('@') if jid.nil? || jid.empty?
          log.info("Authenticating user: %s" % jid)
          @outstanding = true
          begin
            user = stream.storage.authenticate(jid, password)
            finish(user || SaslErrors::NotAuthorized.new)
          rescue Exception => e
            log.error("Failed to authenticate: #{e.to_s}")
            finish(SaslErrors::TemporaryAuthFailure.new)
          end
        end

        def finish(result)
          @outstanding = false
          if result.kind_of?(Exception)
            send_auth_fail(result)
          else
            stream.user = result
            log.info("Authentication succeeded: %s" % stream.user.jid)
            send_auth_success
          end
        end

        def send_auth_success
          stream.write(SUCCESS)
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
