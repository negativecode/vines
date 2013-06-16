# encoding: UTF-8

require 'test_helper'

describe Vines::Stream::Http::Start do
  before do
    @stream = MiniTest::Mock.new
    @state = Vines::Stream::Http::Start.new(@stream)
  end

  def test_missing_body_raises_error
    node = node('<presence type="unavailable"/>')
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  def test_body_with_missing_namespace_raises_error
    node = node('<body rid="42" sid="12"/>')
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  def test_missing_session_starts_stream
    EM.run do
      node = node('<body xmlns="http://jabber.org/protocol/httpbind" rid="42" sid="12"/>')
      @stream.expect(:start, nil, [node])
      @stream.expect(:advance, nil, [Vines::Stream::Http::Auth.new(@stream)])
      @state.node(node)
      assert @stream.verify
      EM.stop
    end
  end

  def test_valid_session_resumes_stream
    EM.run do
      node = node('<body xmlns="http://jabber.org/protocol/httpbind" rid="42" sid="123"/>')
      session = MiniTest::Mock.new
      session.expect(:resume, nil, [@stream, node])
      Vines::Stream::Http::Sessions['123'] = session
      @state.node(node)
      assert @stream.verify
      assert session.verify
      EM.stop
    end
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
