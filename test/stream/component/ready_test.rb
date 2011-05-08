# encoding: UTF-8

require 'vines'
require 'ext/nokogiri'
require 'minitest/mock'
require 'test/unit'

class ComponentReadyTest < Test::Unit::TestCase
  STANZAS = []

  def setup
    @stream = MiniTest::Mock.new
    @state = Vines::Stream::Component::Ready.new(@stream, nil)
    def @state.to_stanza(node)
      if node.name == 'bogus'
        nil
      else
        MiniTest::Mock.new.tap do |stanza|
          if node['to'] == 'hatter@wonderland.lit'
            stanza.expect(:local?, true)
          else
            stanza.expect(:local?, false)
            stanza.expect(:route, nil)
          end
          ComponentReadyTest::STANZAS << stanza
        end
      end
    end
  end

  def teardown
    STANZAS.clear
  end

  def test_missing_to_and_from_addresses
    node = node('<message/>')
    assert_raise(Vines::StreamErrors::ImproperAddressing) { @state.node(node) }
    assert_equal 1, STANZAS.size
    assert @stream.verify
  end

  def test_missing_from_address
    @stream.expect(:remote_domain, 'tea.wonderland.lit')
    node = node(%q{<message to="hatter@wonderland.lit"/>})
    assert_raise(Vines::StreamErrors::ImproperAddressing) { @state.node(node) }
    assert_equal 1, STANZAS.size
    assert @stream.verify
  end

  def test_missing_to_address
    node = node(%q{<message from="alice@tea.wonderland.lit"/>})
    assert_raise(Vines::StreamErrors::ImproperAddressing) { @state.node(node) }
    assert_equal 1, STANZAS.size
    assert @stream.verify
  end

  def test_invalid_from_address
    @stream.expect(:remote_domain, 'tea.wonderland.lit')
    node = node(%q{<message from="alice@bogus.wonderland.lit" to="hatter@wonderland.lit"/>})
    assert_raise(Vines::StreamErrors::ImproperAddressing) { @state.node(node) }
    assert_equal 1, STANZAS.size
    assert @stream.verify
  end

  def test_unsupported_stanza_type
    node = node('<bogus/>')
    assert_raise(Vines::StreamErrors::UnsupportedStanzaType) { @state.node(node) }
    assert STANZAS.empty?
    assert @stream.verify
  end

  def test_remote_message_routes
    @stream.expect(:remote_domain, 'tea.wonderland.lit')
    node = node(%q{<message from="alice@tea.wonderland.lit" to="romeo@verona.lit"/>})
    assert_nothing_raised { @state.node(node) }
    assert_equal 1, STANZAS.size
    assert STANZAS.map {|s| s.verify }.all?
    assert @stream.verify
  end

  def test_local_message_processes
    node = node(%q{<message from="alice@tea.wonderland.lit" to="hatter@wonderland.lit"/>})
    @stream.expect(:remote_domain, 'tea.wonderland.lit')

    @recipient = MiniTest::Mock.new
    @recipient.expect(:write, nil, [node])

    @router = MiniTest::Mock.new
    @router.expect(:connected_resources, [@recipient], ['hatter@wonderland.lit'])
    @stream.expect(:router, @router)

    assert_nothing_raised { @state.node(node) }
    assert_equal 1, STANZAS.size
    assert STANZAS.map {|s| s.verify }.all?
    assert @stream.verify
    assert @router.verify
    assert @recipient.verify
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
