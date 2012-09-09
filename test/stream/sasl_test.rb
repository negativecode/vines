# encoding: UTF-8

require 'test_helper'

describe Vines::Stream::SASL do
  let(:stream)  { MiniTest::Mock.new }
  let(:sasl)    { Vines::Stream::SASL.new(stream) }
  let(:storage) { MiniTest::Mock.new }
  let(:romeo)   { Vines::User.new(jid: 'romeo@verona.lit') }

  before do
    def sasl.log
      Class.new do
        def method_missing(*args)
          # do nothing
        end
      end.new
    end
  end

  describe '#plain_auth' do
    before do
      stream.expect :domain, 'verona.lit'
    end

    it 'fails with empty input' do
      -> { sasl.plain_auth(nil) }.must_raise Vines::SaslErrors::IncorrectEncoding
      -> { sasl.plain_auth('') }.must_raise Vines::SaslErrors::NotAuthorized
    end

    it 'fails with plain text' do
      -> { sasl.plain_auth('bogus') }.must_raise Vines::SaslErrors::IncorrectEncoding
    end

    it 'fails with incorrectly encoded base64 text' do
      -> { sasl.plain_auth('=dmVyb25hLmxpdA==') }.must_raise Vines::SaslErrors::IncorrectEncoding
      -> { sasl.plain_auth("dmVyb25hLmxpdA==\n") }.must_raise Vines::SaslErrors::IncorrectEncoding
    end

    it 'fails when authzid does not match authcid username' do
      encoded = Base64.strict_encode64("juliet@verona.lit\x00romeo\x00secr3t")
      -> { sasl.plain_auth(encoded) }.must_raise Vines::SaslErrors::InvalidAuthzid
      stream.verify
    end

    it 'fails when authzid does not match authcid domain' do
      encoded = Base64.strict_encode64("romeo@wonderland.lit\x00romeo\x00secr3t")
      -> { sasl.plain_auth(encoded) }.must_raise Vines::SaslErrors::InvalidAuthzid
      stream.verify
    end

    it 'fails when username and password are missing' do
      encoded = Base64.strict_encode64("\x00\x00")
      -> { sasl.plain_auth(encoded) }.must_raise Vines::SaslErrors::NotAuthorized
    end

    it 'fails when username is missing' do
      encoded = Base64.strict_encode64("\x00\x00secr3t")
      -> { sasl.plain_auth(encoded) }.must_raise Vines::SaslErrors::NotAuthorized
    end

    it 'fails when password is missing with delimiter' do
      encoded = Base64.strict_encode64("\x00romeo\x00")
      -> { sasl.plain_auth(encoded) }.must_raise Vines::SaslErrors::NotAuthorized
    end

    it 'fails when password is missing' do
      encoded = Base64.strict_encode64("\x00romeo")
      -> { sasl.plain_auth(encoded) }.must_raise Vines::SaslErrors::NotAuthorized
    end

    it 'fails with invalid jid' do
      encoded = Base64.strict_encode64("\x00#{'a' * 1024}\x00secr3t")
      -> { sasl.plain_auth(encoded) }.must_raise Vines::SaslErrors::NotAuthorized
      stream.verify
    end

    it 'fails with invalid password' do
      storage.expect :authenticate, nil, [romeo.jid, 'secr3t']
      stream.expect :storage, storage

      encoded = Base64.strict_encode64("\x00romeo\x00secr3t")
      -> { sasl.plain_auth(encoded) }.must_raise Vines::SaslErrors::NotAuthorized

      stream.verify
      storage.verify
    end

    it 'passes with valid password' do
      storage.expect :authenticate, romeo, [romeo.jid, 'secr3t']
      stream.expect :storage, storage

      encoded = Base64.strict_encode64("\x00romeo\x00secr3t")
      sasl.plain_auth(encoded).must_equal romeo

      stream.verify
      storage.verify
    end

    it 'passes with valid password and authzid provided by strophe and blather' do
      storage.expect :authenticate, romeo, [romeo.jid, 'secr3t']
      stream.expect :storage, storage

      encoded = Base64.strict_encode64("romeo@Verona.LIT\x00romeo\x00secr3t")
      sasl.plain_auth(encoded).must_equal romeo

      stream.verify
      storage.verify
    end

    it 'passes with valid password and authzid provided by smack' do
      storage.expect :authenticate, romeo, [romeo.jid, 'secr3t']
      stream.expect :storage, storage

      encoded = Base64.strict_encode64("romeo\x00romeo\x00secr3t")
      sasl.plain_auth(encoded).must_equal romeo

      stream.verify
      storage.verify
    end

    it 'raises temporary-auth-failure when storage backend fails' do
      storage = Class.new do
        def authenticate(*args)
          raise 'boom'
        end
      end.new

      stream.expect :storage, storage
      encoded = Base64.strict_encode64("\x00romeo\x00secr3t")
      -> { sasl.plain_auth(encoded) }.must_raise Vines::SaslErrors::TemporaryAuthFailure
      stream.verify
    end
  end

  describe '#external_auth' do
    it 'fails with empty input' do
      stream.expect :remote_domain, 'verona.lit'
      -> { sasl.external_auth(nil) }.must_raise Vines::SaslErrors::IncorrectEncoding
      -> { sasl.external_auth('') }.must_raise Vines::SaslErrors::InvalidAuthzid
      stream.verify
    end

    it 'fails with plain text' do
      -> { sasl.external_auth('bogus') }.must_raise Vines::SaslErrors::IncorrectEncoding
      stream.verify
    end

    it 'fails with incorrectly encoded base64 text' do
      -> { sasl.external_auth('=dmVyb25hLmxpdA==') }.must_raise Vines::SaslErrors::IncorrectEncoding
      -> { sasl.external_auth("dmVyb25hLmxpdA==\n") }.must_raise Vines::SaslErrors::IncorrectEncoding
      stream.verify
    end

    it 'passes with empty authzid and matching cert' do
      stream.expect :remote_domain, 'verona.lit'
      stream.expect :cert_domain_matches?, true, ['verona.lit']
      sasl.external_auth('=').must_equal true
      stream.verify
    end

    it 'fails with empty authzid and non-matching cert' do
      stream.expect :remote_domain, 'verona.lit'
      stream.expect :cert_domain_matches?, false, ['verona.lit']
      -> { sasl.external_auth('=') }.must_raise Vines::SaslErrors::NotAuthorized
      stream.verify
    end

    it 'fails when authzid does not match stream from address' do
      stream.expect :remote_domain, 'not.verona.lit'
      -> { sasl.external_auth('dmVyb25hLmxpdA==') }.must_raise Vines::SaslErrors::InvalidAuthzid
      stream.verify
    end

    it 'passes when authzid matches stream from address' do
      stream.expect :remote_domain, 'verona.lit'
      stream.expect :remote_domain, 'verona.lit'
      stream.expect :cert_domain_matches?, true, ['verona.lit']
      sasl.external_auth('dmVyb25hLmxpdA==').must_equal true
      stream.verify
    end
  end
end
