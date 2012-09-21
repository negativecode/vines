# encoding: UTF-8

require 'test_helper'

describe Vines::XmppError do
  describe Vines::SaslErrors do
    it 'does not require a text element' do
      expected = %q{<failure xmlns="urn:ietf:params:xml:ns:xmpp-sasl"><temporary-auth-failure/></failure>}
      Vines::SaslErrors::TemporaryAuthFailure.new.to_xml.must_equal expected
    end

    it 'includes a text element when message is given' do
      text = %q{<text xml:lang="en">busted</text>}
      expected = %q{<failure xmlns="urn:ietf:params:xml:ns:xmpp-sasl"><temporary-auth-failure/>%s</failure>} % text
      Vines::SaslErrors::TemporaryAuthFailure.new('busted').to_xml.must_equal expected
    end
  end

  describe Vines::StreamErrors do
    it 'does not require a text element' do
      expected = %q{<stream:error><internal-server-error xmlns="urn:ietf:params:xml:ns:xmpp-streams"/></stream:error>}
      Vines::StreamErrors::InternalServerError.new.to_xml.must_equal expected
    end

    it 'includes a text element when message is given' do
      text = %q{<text xmlns="urn:ietf:params:xml:ns:xmpp-streams" xml:lang="en">busted</text>}
      expected = %q{<stream:error><internal-server-error xmlns="urn:ietf:params:xml:ns:xmpp-streams"/>%s</stream:error>} % text
      Vines::StreamErrors::InternalServerError.new('busted').to_xml.must_equal expected
    end
  end

  describe Vines::StanzaErrors do
    it 'raises when given a bad type' do
      node = node('<message/>')
      -> { Vines::StanzaErrors::BadRequest.new(node, 'bogus') }.must_raise RuntimeError
    end

    it 'raises when given a bad stanza' do
      node = node('<bogus/>')
      -> { Vines::StanzaErrors::BadRequest.new(node, 'modify') }.must_raise RuntimeError
    end

    it 'does not require a text element' do
      error = %q{<error type="modify"><bad-request xmlns="urn:ietf:params:xml:ns:xmpp-stanzas"/></error>}
      expected = %q{<message from="hatter@wonderland.lit" to="alice@wonderland.lit" type="error">%s</message>} % error
      node = node(%Q{<message from="alice@wonderland.lit" to="hatter@wonderland.lit"/>})
      Vines::StanzaErrors::BadRequest.new(node, 'modify').to_xml.must_equal expected
    end

    it 'includes a text element when message is given' do
      text = %q{<text xmlns="urn:ietf:params:xml:ns:xmpp-stanzas" xml:lang="en">busted</text>}
      error = %q{<error type="modify"><bad-request xmlns="urn:ietf:params:xml:ns:xmpp-stanzas"/>%s</error>} % text
      expected = %q{<message id="42" type="error">%s</message>} % error
      node = node(%Q{<message id="42"/>})
      Vines::StanzaErrors::BadRequest.new(node, 'modify', 'busted').to_xml.must_equal expected
    end
  end
end
