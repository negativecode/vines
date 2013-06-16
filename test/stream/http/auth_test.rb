# encoding: UTF-8

require 'test_helper'

describe Vines::Stream::Http::Auth do
  before do
    @stream = MiniTest::Mock.new
    @state = Vines::Stream::Http::Auth.new(@stream, nil)
  end

  def test_missing_body_raises_error
    node = node('<presence type="unavailable"/>')
    @stream.expect(:valid_session?, true, [nil])
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  def test_body_with_missing_namespace_raises_error
    node = node('<body rid="42" sid="12"/>')
    @stream.expect(:valid_session?, true, ['12'])
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  def test_missing_rid_raises_error
    node = node('<body xmlns="http://jabber.org/protocol/httpbind" sid="12"/>')
    @stream.expect(:valid_session?, true, ['12'])
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  def test_invalid_session_raises_error
    @stream.expect(:valid_session?, false, ['12'])
    node = node('<body xmlns="http://jabber.org/protocol/httpbind" rid="42" sid="12"/>')
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
    assert @stream.verify
  end

  def test_empty_body_raises_error
    node = node('<body xmlns="http://jabber.org/protocol/httpbind" rid="42" sid="12"/>')
    @stream.expect(:valid_session?, true, ['12'])
    @stream.expect(:parse_body, [], [node])
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
    assert @stream.verify
  end

  def test_body_with_two_children_raises_error
    node = node('<body xmlns="http://jabber.org/protocol/httpbind" rid="42" sid="12"><message/><message/></body>')
    message = node('<message/>')
    @stream.expect(:valid_session?, true, ['12'])
    @stream.expect(:parse_body, [message, message], [node])
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
    assert @stream.verify
  end

  def test_valid_body_processes
    auth = node(%Q{<auth xmlns="#{Vines::NAMESPACES[:sasl]}" mechanism="PLAIN"/>})
    node = node('<body xmlns="http://jabber.org/protocol/httpbind" rid="42" sid="12"></body>')
    node << auth
    @stream.expect(:valid_session?, true, ['12'])
    @stream.expect(:parse_body, [auth], [node])
    # this error means we correctly called the parent method Client#node
    @stream.expect(:error, nil, [Vines::SaslErrors::MalformedRequest.new])
    @state.node(node)
    assert @stream.verify
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
