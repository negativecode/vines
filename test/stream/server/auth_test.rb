# encoding: UTF-8

require 'test_helper'

describe Vines::Stream::Server::Auth do
  # disable logging for tests
  Class.new.extend(Vines::Log).log.level = Logger::FATAL

  subject      { Vines::Stream::Server::Auth.new(stream) }
  let(:stream) { MiniTest::Mock.new }

  before do
    class << stream
      attr_accessor :remote_domain
    end
    stream.remote_domain = 'wonderland.lit'
  end

  describe 'when given a valid authzid' do
    before do
      stream.expect :cert_domain_matches?, true, ['wonderland.lit']
      stream.expect :write, nil, ['<success xmlns="urn:ietf:params:xml:ns:xmpp-sasl"/>']
      stream.expect :advance, nil, [Vines::Stream::Server::FinalRestart]
      stream.expect :reset, nil
      stream.expect :authentication_mechanisms, ['EXTERNAL']
    end

    it 'passes external auth with empty authzid' do
      node = external('=')
      subject.node(node)
      stream.verify
    end

    it 'passes external auth with authzid matching from domain' do
      node = external(Base64.strict_encode64('wonderland.lit'))
      subject.node(node)
      stream.verify
    end
  end

  describe 'when given an invalid authzid' do
    before do
      stream.expect :write, nil, ['</stream:stream>']
      stream.expect :close_connection_after_writing, nil
      stream.expect :error, nil, [Vines::SaslErrors::InvalidAuthzid]
      stream.expect :authentication_mechanisms, ['EXTERNAL']
    end

    it 'fails external auth with mismatched from domain' do
      node = external(Base64.strict_encode64('verona.lit'))
      subject.node(node)
      stream.verify
    end
  end

  private

  def external(authzid)
    node(%Q{<auth xmlns="urn:ietf:params:xml:ns:xmpp-sasl" mechanism="EXTERNAL">#{authzid}</auth>})
  end
end
