# encoding: UTF-8

require 'vines'
require 'ext/nokogiri'
require 'minitest/autorun'

class StanzaTest < MiniTest::Unit::TestCase
  def setup
    @stream = MiniTest::Mock.new
  end

  def test_validate_missing_addresses
    node = node(%Q{<message>hello!</message>})
    stanza = Vines::Stanza::Message.new(node, @stream)
    assert_nil stanza.validate_to
    assert_nil stanza.validate_from
  end

  def test_validate_valid_addresses
    alice = Vines::JID.new('alice@wonderland.lit/tea')
    romeo = Vines::JID.new('romeo@verona.lit/balcony')
    node = node(%Q{<message from="#{alice}" to="#{romeo}">hello!</message>})

    stanza = Vines::Stanza::Message.new(node, @stream)
    assert_equal romeo, stanza.validate_to
    assert_equal alice, stanza.validate_from
  end

  def test_validate_invalid_addresses
    alice = Vines::JID.new('alice@wonderland.lit/tea')
    romeo = Vines::JID.new('romeo@verona.lit/balcony')
    node = node(%Q{<message from="a lice@wonderland.lit" to="romeo@v erona.lit">hello!</message>})

    stanza = Vines::Stanza::Message.new(node, @stream)
    assert_raises(Vines::StanzaErrors::JidMalformed) { stanza.validate_to }
    assert_raises(Vines::StanzaErrors::JidMalformed) { stanza.validate_from }
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
