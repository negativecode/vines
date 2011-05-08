# encoding: UTF-8

require 'vines'
require 'minitest/mock'
require 'test/unit'

class ClientReadyTest < Test::Unit::TestCase
  STANZAS = []

  def setup
    @stream = MiniTest::Mock.new
    @state = Vines::Stream::Client::Ready.new(@stream, nil)
    def @state.to_stanza(node)
      if node.name == 'bogus'
        nil
      else
        MiniTest::Mock.new.tap do |stanza|
          stanza.expect(:process, nil)
          ClientReadyTest::STANZAS << stanza
        end
      end
    end
  end

  def teardown
    STANZAS.clear
  end

  def test_good_node_processes
    node = node('<message/>')
    assert_nothing_raised { @state.node(node) }
    assert_equal 1, STANZAS.size
    assert STANZAS.map {|s| s.verify }.all?
  end

  def test_unsupported_stanza_type
    node = node('<bogus/>')
    assert_raise(Vines::StreamErrors::UnsupportedStanzaType) { @state.node(node) }
    assert STANZAS.empty?
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
