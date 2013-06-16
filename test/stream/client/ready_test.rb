# encoding: UTF-8

require 'test_helper'

describe Vines::Stream::Client::Ready do
  STANZAS = []

  before do
    @stream = MiniTest::Mock.new
    @state = Vines::Stream::Client::Ready.new(@stream, nil)
    def @state.to_stanza(node)
      if node.name == 'bogus'
        nil
      else
        stanza = MiniTest::Mock.new
        stanza.expect(:process, nil)
        stanza.expect(:validate_to, nil)
        stanza.expect(:validate_from, nil)
        STANZAS << stanza
        stanza
      end
    end
  end

  after do
    STANZAS.clear
  end

  it 'processes a valid node' do
    node = node('<message/>')
    @state.node(node)
    assert_equal 1, STANZAS.size
    assert STANZAS.map {|s| s.verify }.all?
  end

  it 'raises an unsupported-stanza-type stream error for invalid node' do
    node = node('<bogus/>')
    assert_raises(Vines::StreamErrors::UnsupportedStanzaType) { @state.node(node) }
    assert STANZAS.empty?
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
