# encoding: UTF-8

require 'test_helper'

class HandshakeTest < MiniTest::Unit::TestCase
  def setup
    @stream = MiniTest::Mock.new
    @state = Vines::Stream::Component::Handshake.new(@stream)
  end

  def test_invalid_element
    node = node('<message/>')
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  def test_missing_text
    @stream.expect(:secret, 'secr3t')
    node = node('<handshake/>')
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
    assert @stream.verify
  end

  def test_invalid_secret
    @stream.expect(:secret, 'secr3t')
    node = node('<handshake>bogus</handshake>')
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
    assert @stream.verify
  end

  def test_valid_secret
    router = MiniTest::Mock.new
    router.expect(:<<, nil, [@stream])
    @stream.expect(:router, router)
    @stream.expect(:secret, 'secr3t')
    @stream.expect(:write, nil, ['<handshake/>'])
    @stream.expect(:advance, nil, [Vines::Stream::Component::Ready.new(@stream)])
    node = node('<handshake>secr3t</handshake>')
    @state.node(node)
    assert @stream.verify
    assert router.verify
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
