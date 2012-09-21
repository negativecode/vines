# encoding: UTF-8

require 'test_helper'

class SessionTest < MiniTest::Unit::TestCase
  def test_session
    stream = MiniTest::Mock.new
    stream.expect(:domain, 'wonderland.lit')
    stream.expect(:user, Vines::User.new(jid: 'alice@wonderland.lit/tea'))
    expected = node(%q{<iq from="wonderland.lit" id="42" to="alice@wonderland.lit/tea" type="result"/>})
    stream.expect(:write, nil, [expected])

    node = node(%q{<iq id="42" type="set"><session xmlns="urn:ietf:params:xml:ns:xmpp-session"/></iq>})
    stanza = Vines::Stanza::Iq::Session.new(node, stream)
    stanza.process
    assert stream.verify
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
