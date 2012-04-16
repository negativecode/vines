# encoding: UTF-8

module Vines
  class Stream
    # Provides plain (username/password) and external (TLS certificate) SASL
    # authentication to client and server streams.
    class SASL
      include Vines::Log
      EMPTY = '='.freeze

      def initialize(stream)
        @stream = stream
      end

      # Authenticate s2s streams, comparing their domain to their SSL certificate.
      # Return +true+ if the base64 encoded domain matches the TLS certificate
      # presented earlier in stream negotiation. Raise a +SaslError+ if
      # authentication failed.
      # http://xmpp.org/extensions/xep-0178.html#s2s
      def external_auth(encoded)
        unless encoded == EMPTY
          authzid = decode64(encoded)
          matches_from = (authzid == @stream.remote_domain)
          raise SaslErrors::InvalidAuthzid unless matches_from
        end
        matches_from = @stream.cert_domain_matches?(@stream.remote_domain)
        matches_from or raise SaslErrors::NotAuthorized
      end

      # Authenticate c2s streams using a username and password. Return the
      # authenticated +User+ or raise a +SaslError+ if authentication failed.
      def plain_auth(encoded)
        jid, password = decode_credentials(encoded)
        user = authenticate(jid, password)
        user or raise SaslErrors::NotAuthorized
      end

      private

      # Storage backends should not raise errors, but if an unexpected error
      # occurs during authentication, convert it to a temporary-auth-failure.
      # Return the authenticated +User+ or +nil+ if authentication failed.
      def authenticate(jid, password)
        log.info("Authenticating user: %s" % jid)
        @stream.storage.authenticate(jid, password).tap do |user|
          log.info("Authentication succeeded: %s" % user.jid) if user
        end
      rescue => e
        log.error("Failed to authenticate: #{e.to_s}")
        raise SaslErrors::TemporaryAuthFailure
      end

      # Return the +JID+ and password decoded from the base64 encoded SASL PLAIN
      # credentials formatted as authzid\0authcid\0password.
      # http://tools.ietf.org/html/rfc6120#section-6.3.8
      # http://tools.ietf.org/html/rfc4616
      def decode_credentials(encoded)
        authzid, node, password = decode64(encoded).split("\x00")
        raise SaslErrors::NotAuthorized if node.nil? || node.empty? || password.nil? || password.empty?
        jid = JID.new(node, @stream.domain) rescue (raise SaslErrors::NotAuthorized)
        raise SaslErrors::InvalidAuthzid unless authzid.nil? || authzid.empty? || authzid.downcase == jid.to_s
        [jid, password]
      end

      # Decode the base64 encoded string, raising an error for invalid data.
      # http://tools.ietf.org/html/rfc6120#section-13.9.1
      def decode64(encoded)
        Base64.strict_decode64(encoded)
      rescue
        raise SaslErrors::IncorrectEncoding
      end
    end
  end
end
