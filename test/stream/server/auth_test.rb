# encoding: UTF-8

require 'vines'
require 'minitest/autorun'

describe Vines::Stream::Server::Auth do
  # disable logging for tests
  Class.new.extend(Vines::Log).log.level = Logger::FATAL

  before do
    @stream = MiniTest::Mock.new
    @state = Vines::Stream::Server::Auth.new(@stream)
  end

  describe 'external auth' do
    it 'passes with empty authzid' do
      @stream.expect(:remote_domain, 'wonderland.lit')
      @stream.expect(:cert_domain_matches?, true, ['wonderland.lit'])
      @stream.expect(:write, nil, ['<success xmlns="urn:ietf:params:xml:ns:xmpp-sasl"/>'])
      @stream.expect(:advance, nil, [Vines::Stream::Server::FinalRestart])
      @stream.expect(:reset, nil)
      @stream.expect(:authentication_mechanisms, ['EXTERNAL'])
      node = node(%Q{<auth xmlns="urn:ietf:params:xml:ns:xmpp-sasl" mechanism="EXTERNAL">=</auth>})
      @state.node(node)
      assert @stream.verify
    end

    it 'passes when authzid matches from domain' do
      @stream.expect(:remote_domain, 'wonderland.lit')
      @stream.expect(:cert_domain_matches?, true, ['wonderland.lit'])
      @stream.expect(:write, nil, ['<success xmlns="urn:ietf:params:xml:ns:xmpp-sasl"/>'])
      @stream.expect(:advance, nil, [Vines::Stream::Server::FinalRestart])
      @stream.expect(:reset, nil)
      @stream.expect(:authentication_mechanisms, ['EXTERNAL'])
      node = node(%Q{<auth xmlns="urn:ietf:params:xml:ns:xmpp-sasl" mechanism="EXTERNAL">#{Base64.strict_encode64('wonderland.lit')}</auth>})
      @state.node(node)
      assert @stream.verify
    end

    it 'fails when authzid does not match from domain' do
      @stream.expect(:remote_domain, 'wonderland.lit')
      @stream.expect(:write, nil, ['</stream:stream>'])
      @stream.expect(:close_connection_after_writing, nil)
      @stream.expect(:error, nil, [Vines::SaslErrors::InvalidAuthzid])
      @stream.expect(:authentication_mechanisms, ['EXTERNAL'])
      node = node(%Q{<auth xmlns="urn:ietf:params:xml:ns:xmpp-sasl" mechanism="EXTERNAL">#{Base64.strict_encode64('verona.lit')}</auth>})
      @state.node(node)
      assert @stream.verify
    end
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
