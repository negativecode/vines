# encoding: UTF-8

module Vines
  # A module for utility methods with no better home.
  module Kit
    # Create a hex-encoded, SHA-512 HMAC of the data, using the secret key.
    def self.hmac(key, data)
      digest = OpenSSL::Digest.respond_to?(:new) ? OpenSSL::Digest.new("sha512") : OpenSSL::Digest::Digest.new("sha512")
      OpenSSL::HMAC.hexdigest(digest, key, data)
    end

    # Generates a random uuid per rfc 4122 that's useful for including in
    # stream, iq, and other xmpp stanzas.
    def self.uuid
      SecureRandom.uuid
    end

    # Generates a random 128 character authentication token.
    def self.auth_token
      SecureRandom.hex(64)
    end
  end
end
