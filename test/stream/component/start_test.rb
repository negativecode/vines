# encoding: UTF-8

require 'vines'
require 'minitest/mock'
require 'test/unit'

class ComponentStartTest < Test::Unit::TestCase
  def setup
    @stream = MiniTest::Mock.new
    @state = Vines::Stream::Component::Start.new(@stream)
  end

  def test_invalid_element
    node = node('<message/>')
    assert_raise(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  def test_missing_stream_namespace
    node = node('<stream:stream/>')
    assert_raise(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  def test_invalid_stream_namespace
    node = node('<stream:stream xmlns="bogus"/>')
    assert_raise(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  def test_valid_stream_header
    node = node(%q{<stream:stream xmlns:stream="http://etherx.jabber.org/streams" xmlns="jabber:component:accept" to="tea.wonderland.lit"/>})
    @stream.expect(:start, nil, [node])
    @stream.expect(:advance, nil, [Vines::Stream::Component::Handshake.new(@stream)])
    assert_nothing_raised { @state.node(node) }
    assert @stream.verify
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
