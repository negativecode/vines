# encoding: UTF-8

require 'vines'
require 'test/unit'

class ErrorTest < Test::Unit::TestCase
  def test_sasl_error_without_text
    expected = %q{<failure xmlns="urn:ietf:params:xml:ns:xmpp-sasl"><temporary-auth-failure/></failure>}
    assert_equal expected, Vines::SaslErrors::TemporaryAuthFailure.new.to_xml
  end

  def test_sasl_error_with_text
    text = %q{<text xml:lang="en">busted</text>}
    expected = %q{<failure xmlns="urn:ietf:params:xml:ns:xmpp-sasl"><temporary-auth-failure/>%s</failure>} % text
    assert_equal expected, Vines::SaslErrors::TemporaryAuthFailure.new('busted').to_xml
  end

  def test_stream_error_without_text
    expected = %q{<stream:error><internal-server-error xmlns="urn:ietf:params:xml:ns:xmpp-streams"/></stream:error>}
    assert_equal expected, Vines::StreamErrors::InternalServerError.new.to_xml
  end

  def test_stream_error_with_text
    text = %q{<text xmlns="urn:ietf:params:xml:ns:xmpp-streams" xml:lang="en">busted</text>}
    expected = %q{<stream:error><internal-server-error xmlns="urn:ietf:params:xml:ns:xmpp-streams"/>%s</stream:error>} % text
    assert_equal expected, Vines::StreamErrors::InternalServerError.new('busted').to_xml
  end

  def test_stanza_error_with_bad_type
    node = node('<message/>')
    assert_raises(RuntimeError) { Vines::StanzaErrors::BadRequest.new(node, 'bogus') }
  end

  def test_stanza_error_with_bad_stanza
    node = node('<bogus/>')
    assert_raises(RuntimeError) { Vines::StanzaErrors::BadRequest.new(node, 'modify') }
  end

  def test_stanza_error_without_text
    error = %q{<error type="modify"><bad-request xmlns="urn:ietf:params:xml:ns:xmpp-stanzas"/></error>}
    expected = %q{<message from="hatter@wonderland.lit" to="alice@wonderland.lit" type="error">%s</message>} % error
    node = node(%Q{<message from="alice@wonderland.lit" to="hatter@wonderland.lit"/>})
    assert_equal expected, Vines::StanzaErrors::BadRequest.new(node, 'modify').to_xml
  end

  def test_stanza_error_with_text
    text = %q{<text xmlns="urn:ietf:params:xml:ns:xmpp-stanzas" xml:lang="en">busted</text>}
    error = %q{<error type="modify"><bad-request xmlns="urn:ietf:params:xml:ns:xmpp-stanzas"/>%s</error>} % text
    expected = %q{<message id="42" type="error">%s</message>} % error
    node = node(%Q{<message id="42"/>})
    assert_equal expected, Vines::StanzaErrors::BadRequest.new(node, 'modify', 'busted').to_xml
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
