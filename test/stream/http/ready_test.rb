# encoding: UTF-8

require 'vines'
require 'minitest/autorun'

class HttpReadyTest < MiniTest::Unit::TestCase
  def setup
    @stream = MiniTest::Mock.new
    @state = Vines::Stream::Http::Ready.new(@stream, nil)
  end

  def test_missing_body_raises_error
    node = node('<presence type="unavailable"/>')
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  def test_body_with_missing_namespace_raises_error
    node = node('<body rid="42" sid="12"/>')
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  def test_missing_rid_raises_error
    node = node('<body xmlns="http://jabber.org/protocol/httpbind" sid="12"/>')
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  def test_invalid_session_raises_error
    @stream.expect(:valid_session?, false, ['12'])
    node = node('<body xmlns="http://jabber.org/protocol/httpbind" rid="42" sid="12"/>')
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
    assert @stream.verify
  end

  def test_valid_body_processes
    node = node('<body xmlns="http://jabber.org/protocol/httpbind" rid="42" sid="12"/>')
    @stream.expect(:valid_session?, true, ['12'])
    @stream.expect(:parse_body, [], [node])
    @state.node(node)
    assert @stream.verify
  end

  def test_terminate
    node = node('<body xmlns="http://jabber.org/protocol/httpbind" rid="42" sid="12" type="terminate"/>')
    @stream.expect(:valid_session?, true, ['12'])
    @stream.expect(:parse_body, [], [node])
    @stream.expect(:terminate, nil)
    @state.node(node)
    assert @stream.verify
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
