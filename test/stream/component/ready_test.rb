# encoding: UTF-8

require 'vines'
require 'ext/nokogiri'
require 'minitest/autorun'

class ComponentReadyTest < MiniTest::Unit::TestCase
  def setup
    @stream = MiniTest::Mock.new
    @state = Vines::Stream::Component::Ready.new(@stream, nil)
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
    assert_raises(Vines::StreamErrors::ImproperAddressing) { @state.node(node) }
    assert @stream.verify
  end

  def test_unsupported_stanza_type
    node = node('<bogus/>')
    assert_raises(Vines::StreamErrors::UnsupportedStanzaType) { @state.node(node) }
    assert @stream.verify
  end

  def test_remote_message_routes
    @stream.expect(:remote_domain, 'tea.wonderland.lit')
    node = node(%q{<message from="alice@tea.wonderland.lit" to="romeo@verona.lit"/>})

    @router = MiniTest::Mock.new
    @router.expect(:local?, false, [node])
    @router.expect(:route, nil, [node])
    @stream.expect(:router, @router)

    @state.node(node)
    assert @stream.verify
    assert @router.verify
  end

  def test_local_message_processes
    node = node(%q{<message from="alice@tea.wonderland.lit" to="hatter@wonderland.lit"/>})
    @stream.expect(:remote_domain, 'tea.wonderland.lit')

    @recipient = MiniTest::Mock.new
    @recipient.expect(:write, nil, [node])

    @router = MiniTest::Mock.new
    @router.expect(:local?, true, [node])
    @router.expect(:connected_resources, [@recipient], ['hatter@wonderland.lit', 'alice@tea.wonderland.lit'])
    @stream.expect(:router, @router)

    @state.node(node)
    assert @stream.verify
    assert @router.verify
    assert @recipient.verify
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
