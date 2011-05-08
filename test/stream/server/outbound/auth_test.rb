# encoding: UTF-8

require 'vines'
require 'minitest/mock'
require 'test/unit'

class OutboundAuthTest < Test::Unit::TestCase
  def setup
    @stream = MiniTest::Mock.new
    @state = Vines::Stream::Server::Outbound::Auth.new(@stream)
  end

  def test_invalid_element
    node = node('<message/>')
    assert_raise(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  def test_invalid_sasl_element
    node = node(%Q{<message xmlns="#{Vines::NAMESPACES[:sasl]}"/>})
    assert_raise(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  def test_missing_namespace
    node = node('<stream:features/>')
    assert_raise(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  def test_invalid_namespace
    node = node('<stream:features xmlns="bogus"/>')
    assert_raise(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  def test_missing_mechanisms
    node = node(%Q{<stream:features xmlns:stream="http://etherx.jabber.org/streams"/>})
    assert_raise(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  def test_missing_mechanisms_namespace
    node = node(%Q{<stream:features xmlns:stream="http://etherx.jabber.org/streams"><mechanisms/></stream:features>})
    assert_raise(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  def test_missing_mechanism
    mechanisms = %q{<mechanisms xmlns="urn:ietf:params:xml:ns:xmpp-sasl"/>}
    node = node(%Q{<stream:features xmlns:stream="http://etherx.jabber.org/streams">#{mechanisms}</stream:features>})
    assert_raise(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  def test_missing_mechanism_text
    mechanisms = %q{<mechanisms xmlns="urn:ietf:params:xml:ns:xmpp-sasl"><mechanism></mechanism></mechanisms>}
    node = node(%Q{<stream:features xmlns:stream="http://etherx.jabber.org/streams">#{mechanisms}</stream:features>})
    assert_raise(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  def test_invalid_mechanism_text
    mechanisms = %q{<mechanisms xmlns="urn:ietf:params:xml:ns:xmpp-sasl"><mechanism>BOGUS</mechanism></mechanisms>}
    node = node(%Q{<stream:features xmlns:stream="http://etherx.jabber.org/streams">#{mechanisms}</stream:features>})
    assert_raise(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  def test_valid_mechanism
    @stream.expect(:domain, 'wonderland.lit')
    expected = %Q{<auth xmlns="urn:ietf:params:xml:ns:xmpp-sasl" mechanism="EXTERNAL">d29uZGVybGFuZC5saXQ=</auth>}
    @stream.expect(:write, nil, [expected])
    @stream.expect(:advance, nil, [Vines::Stream::Server::Outbound::AuthResult.new(@stream)])
    mechanisms = %q{<mechanisms xmlns="urn:ietf:params:xml:ns:xmpp-sasl"><mechanism>EXTERNAL</mechanism></mechanisms>}
    node = node(%Q{<stream:features xmlns:stream="http://etherx.jabber.org/streams">#{mechanisms}</stream:features>})
    assert_nothing_raised { @state.node(node) }
    assert @stream.verify
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
