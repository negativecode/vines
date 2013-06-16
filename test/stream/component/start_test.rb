# encoding: UTF-8

require 'test_helper'

describe Vines::Stream::Component::Start do
  before do
    @stream = MiniTest::Mock.new
    @state = Vines::Stream::Component::Start.new(@stream)
  end

  it 'raises not-authorized stream error for invalid element' do
    node = node('<message/>')
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  it 'raises not-authorized stream error for missing stream namespace' do
    node = node('<stream:stream/>')
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  it 'raises not-authorized stream error for invalid stream namespace' do
    node = node('<stream:stream xmlns="bogus"/>')
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  it 'advances the state machine for valid stream header' do
    node = node(%q{<stream:stream xmlns:stream="http://etherx.jabber.org/streams" xmlns="jabber:component:accept" to="tea.wonderland.lit"/>})
    @stream.expect(:start, nil, [node])
    @stream.expect(:advance, nil, [Vines::Stream::Component::Handshake.new(@stream)])
    @state.node(node)
    assert @stream.verify
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
