# encoding: UTF-8

require 'vines'
require 'minitest/autorun'

describe Vines::Stream::SASL do
  before do
    @stream = MiniTest::Mock.new
    @sasl = Vines::Stream::SASL.new(@stream)
    def @sasl.log
      Class.new do
        def method_missing(*args)
          # do nothing
        end
      end.new
    end
  end

  describe '#plain_auth' do
    it 'fails with invalid input' do
      proc { @sasl.plain_auth(nil) }.must_raise Vines::SaslErrors::IncorrectEncoding
      proc { @sasl.plain_auth('') }.must_raise Vines::SaslErrors::NotAuthorized
      proc { @sasl.plain_auth('bogus') }.must_raise Vines::SaslErrors::IncorrectEncoding
      proc { @sasl.plain_auth('=dmVyb25hLmxpdA==') }.must_raise Vines::SaslErrors::IncorrectEncoding
      proc { @sasl.plain_auth("dmVyb25hLmxpdA==\n") }.must_raise Vines::SaslErrors::IncorrectEncoding
    end

    it 'fails when authzid is present' do
      authzid = Base64.strict_encode64("romeo@verona.lit\x00romeo\x00secr3t")
      proc { @sasl.plain_auth(authzid) }.must_raise Vines::SaslErrors::InvalidAuthzid
    end

    it 'fails when username is missing' do
      authzid = Base64.strict_encode64("\x00\x00secr3t")
      proc { @sasl.plain_auth(authzid) }.must_raise Vines::SaslErrors::NotAuthorized
      authzid = Base64.strict_encode64("\x00\x00")
      proc { @sasl.plain_auth(authzid) }.must_raise Vines::SaslErrors::NotAuthorized
    end

    it 'fails when password is missing' do
      authzid = Base64.strict_encode64("\x00romeo\x00")
      proc { @sasl.plain_auth(authzid) }.must_raise Vines::SaslErrors::NotAuthorized
      authzid = Base64.strict_encode64("\x00romeo")
      proc { @sasl.plain_auth(authzid) }.must_raise Vines::SaslErrors::NotAuthorized
    end

    it 'fails with invalid jid' do
      @stream.expect(:domain, 'verona.lit')
      jid = 'a' * 1024
      authzid = Base64.strict_encode64("\x00#{jid}\x00secr3t")
      proc { @sasl.plain_auth(authzid) }.must_raise Vines::SaslErrors::NotAuthorized
      @stream.verify.must_equal true
    end

    it 'fails with invalid password' do
      romeo = Vines::JID.new('romeo@verona.lit')
      storage = MiniTest::Mock.new
      storage.expect(:authenticate, nil, [romeo, 'secr3t'])
      @stream.expect(:domain, 'verona.lit')
      @stream.expect(:storage, storage)

      authzid = Base64.strict_encode64("\x00romeo\x00secr3t")
      proc { @sasl.plain_auth(authzid) }.must_raise Vines::SaslErrors::NotAuthorized
      @stream.verify.must_equal true
      storage.verify.must_equal true
    end

    it 'passes with valid password' do
      romeo = Vines::JID.new('romeo@verona.lit')
      storage = MiniTest::Mock.new
      storage.expect(:authenticate, Vines::User.new(jid: romeo), [romeo, 'secr3t'])
      @stream.expect(:domain, 'verona.lit')
      @stream.expect(:storage, storage)

      authzid = Base64.strict_encode64("\x00romeo\x00secr3t")
      @sasl.plain_auth(authzid).must_equal Vines::User.new(jid: romeo)
      @stream.verify.must_equal true
      storage.verify.must_equal true
    end

    it 'raises temporary-auth-failure when storage backend fails' do
      storage = Class.new do
        def authenticate(*args)
          raise 'boom'
        end
      end.new
      @stream.expect(:domain, 'verona.lit')
      @stream.expect(:storage, storage)

      authzid = Base64.strict_encode64("\x00romeo\x00secr3t")
      proc { @sasl.plain_auth(authzid) }.must_raise Vines::SaslErrors::TemporaryAuthFailure
      @stream.verify.must_equal true
    end
  end

  describe '#external_auth' do
    it 'fails with invalid input' do
      @stream.expect(:remote_domain, 'verona.lit')
      proc { @sasl.external_auth(nil) }.must_raise Vines::SaslErrors::IncorrectEncoding
      proc { @sasl.external_auth('') }.must_raise Vines::SaslErrors::InvalidAuthzid
      proc { @sasl.external_auth('bogus') }.must_raise Vines::SaslErrors::IncorrectEncoding
      proc { @sasl.external_auth('=dmVyb25hLmxpdA==') }.must_raise Vines::SaslErrors::IncorrectEncoding
      proc { @sasl.external_auth("dmVyb25hLmxpdA==\n") }.must_raise Vines::SaslErrors::IncorrectEncoding
      @stream.verify.must_equal true
    end

    it 'passes with empty authzid and matching cert' do
      @stream.expect(:remote_domain, 'verona.lit')
      @stream.expect(:cert_domain_matches?, true, ['verona.lit'])
      @sasl.external_auth('=').must_equal true
      @stream.verify.must_equal true
    end

    it 'fails with empty authzid and non-matching cert' do
      @stream.expect(:remote_domain, 'verona.lit')
      @stream.expect(:cert_domain_matches?, false, ['verona.lit'])
      proc { @sasl.external_auth('=') }.must_raise Vines::SaslErrors::NotAuthorized
      @stream.verify.must_equal true
    end

    it 'fails when authzid does not match stream from address' do
      @stream.expect(:remote_domain, 'not.verona.lit')
      proc { @sasl.external_auth('dmVyb25hLmxpdA==') }.must_raise Vines::SaslErrors::InvalidAuthzid
      @stream.verify.must_equal true
    end

    it 'passes when authzid matches stream from address' do
      @stream.expect(:remote_domain, 'verona.lit')
      @stream.expect(:cert_domain_matches?, true, ['verona.lit'])
      @sasl.external_auth('dmVyb25hLmxpdA==').must_equal true
      @stream.verify.must_equal true
    end
  end
end
