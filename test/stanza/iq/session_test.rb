# encoding: UTF-8

require 'vines'
require 'ext/nokogiri'
require 'minitest/autorun'

class SessionTest < MiniTest::Unit::TestCase
  def test_session
    stream = MiniTest::Mock.new
    stream.expect(:domain, 'wonderland.lit')
    expected = node(%q{<iq from="wonderland.lit" id="42" type="result"/>})
    stream.expect(:write, nil, [expected])

    node = node(
      %q{<iq id="42" to="wonderland.lit" type="set">
        <session xmlns="urn:ietf:params:xml:ns:xmpp-session"/>
      </iq>})

    stanza = Vines::Stanza::Iq::Session.new(node, stream)
    stanza.process
    assert stream.verify
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
