# encoding: UTF-8

require 'tmpdir'
require 'vines'
require 'ext/nokogiri'
require 'minitest/autorun'

class ComponentReadyTest < MiniTest::Unit::TestCase
  def setup
    @stream = MiniTest::Mock.new
    @state  = Vines::Stream::Component::Ready.new(@stream, nil)
    @config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
      end
    end
  end

  def test_missing_to_and_from_addresses
    node = node('<message/>')
    assert_raises(Vines::StreamErrors::ImproperAddressing) { @state.node(node) }
    assert @stream.verify
  end

  def test_missing_from_address
    node = node(%q{<message to="hatter@wonderland.lit"/>})
    assert_raises(Vines::StreamErrors::ImproperAddressing) { @state.node(node) }
    assert @stream.verify
  end

  def test_missing_to_address
    node = node(%q{<message from="alice@tea.wonderland.lit"/>})
    assert_raises(Vines::StreamErrors::ImproperAddressing) { @state.node(node) }
    assert @stream.verify
  end

  def test_invalid_from_address
    @stream.expect(:remote_domain, 'tea.wonderland.lit')
    node = node(%q{<message from="alice@bogus.wonderland.lit" to="hatter@wonderland.lit"/>})
    assert_raises(Vines::StreamErrors::InvalidFrom) { @state.node(node) }
    assert @stream.verify
  end

  def test_unsupported_stanza_type
    node = node('<bogus/>')
    assert_raises(Vines::StreamErrors::UnsupportedStanzaType) { @state.node(node) }
    assert @stream.verify
  end

  def test_remote_message_routes
    node = node(%q{<message from="alice@tea.wonderland.lit" to="romeo@verona.lit"/>})
    @stream.expect(:remote_domain, 'tea.wonderland.lit')
    @stream.expect(:config, @config)
    @stream.expect(:user=, nil, [Vines::User.new(:jid => 'alice@tea.wonderland.lit')])

    @router = MiniTest::Mock.new
    @router.expect(:route, nil, [node])
    @stream.expect(:router, @router)

    @state.node(node)
    assert @stream.verify
    assert @router.verify
  end

  def test_local_message_processes
    node = node(%q{<message from="alice@tea.wonderland.lit" to="hatter@wonderland.lit"/>})
    @stream.expect(:remote_domain, 'tea.wonderland.lit')
    @stream.expect(:config, @config)
    @stream.expect(:user=, nil, [Vines::User.new(:jid => 'alice@tea.wonderland.lit')])
    @stream.expect(:user, Vines::User.new(:jid => 'alice@tea.wonderland.lit'))

    @recipient = MiniTest::Mock.new
    @recipient.expect(:user, Vines::User.new(:jid => 'hatter@wonderland.lit'))
    @recipient.expect(:write, nil, [node])

    @stream.expect(:connected_resources, [@recipient], [Vines::JID.new('hatter@wonderland.lit')])

    @state.node(node)
    assert @stream.verify
    assert @recipient.verify
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
