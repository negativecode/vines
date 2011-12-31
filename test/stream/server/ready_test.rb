# encoding: UTF-8

require 'vines'
require 'minitest/autorun'

class ServerReadyTest < MiniTest::Unit::TestCase
  STANZAS = []

  def setup
    @stream = MiniTest::Mock.new
    @state = Vines::Stream::Server::Ready.new(@stream, nil)
    def @state.to_stanza(node)
      Vines::Stanza.from_node(node, @stream).tap do |stanza|
        def stanza.process
          ServerReadyTest::STANZAS << self
        end if stanza
      end
    end
  end

  def teardown
    STANZAS.clear
  end

  def test_good_node_processes
    config = MiniTest::Mock.new
    config.expect(:local_jid?, true, [Vines::JID.new('romeo@verona.lit')])

    @stream.expect(:config, config)
    @stream.expect(:remote_domain, 'wonderland.lit')
    @stream.expect(:domain, 'verona.lit')
    @stream.expect(:user=, nil, [Vines::User.new(jid: 'alice@wonderland.lit')])

    node = node(%Q{<message from="alice@wonderland.lit" to="romeo@verona.lit"/>})
    @state.node(node)
    assert_equal 1, STANZAS.size
    assert @stream.verify
    assert config.verify
  end

  def test_unsupported_stanza_type
    node = node('<bogus/>')
    assert_raises(Vines::StreamErrors::UnsupportedStanzaType) { @state.node(node) }
    assert STANZAS.empty?
    assert @stream.verify
  end

  def test_improper_addressing_missing_to
    node = node(%Q{<message from="alice@wonderland.lit"/>})
    assert_raises(Vines::StreamErrors::ImproperAddressing) { @state.node(node) }
    assert STANZAS.empty?
    assert @stream.verify
  end

  def test_improper_addressing_invalid_to
    node = node(%Q{<message from="alice@wonderland.lit" to=" "/>})
    assert_raises(Vines::StanzaErrors::JidMalformed) { @state.node(node) }
    assert STANZAS.empty?
    assert @stream.verify
  end

  def test_improper_addressing_missing_from
    node = node(%Q{<message to="romeo@verona.lit"/>})
    assert_raises(Vines::StreamErrors::ImproperAddressing) { @state.node(node) }
    assert STANZAS.empty?
    assert @stream.verify
  end

  def test_improper_addressing_invalid_from
    node = node(%Q{<message from=" " to="romeo@verona.lit"/>})
    assert_raises(Vines::StanzaErrors::JidMalformed) { @state.node(node) }
    assert STANZAS.empty?
    assert @stream.verify
  end

  def test_invalid_from
    @stream.expect(:remote_domain, 'wonderland.lit')
    node = node(%Q{<message from="alice@bogus.lit" to="romeo@verona.lit"/>})
    assert_raises(Vines::StreamErrors::InvalidFrom) { @state.node(node) }
    assert STANZAS.empty?
    assert @stream.verify
  end

  def test_host_unknown
    @stream.expect(:remote_domain, 'wonderland.lit')
    @stream.expect(:domain, 'verona.lit')
    node = node(%Q{<message from="alice@wonderland.lit" to="romeo@bogus.lit"/>})
    assert_raises(Vines::StreamErrors::HostUnknown) { @state.node(node) }
    assert STANZAS.empty?
    assert @stream.verify
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
