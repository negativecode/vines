# encoding: UTF-8

require 'vines'
require 'ext/nokogiri'
require 'minitest/autorun'

class StanzaTest < MiniTest::Unit::TestCase
  def setup
    @alice = Vines::JID.new('alice@wonderland.lit/tea')
    @romeo = Vines::JID.new('romeo@verona.lit/balcony')
    @stream = MiniTest::Mock.new
    @config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir '.' }
      end
    end
  end

  def test_validate_missing_addresses
    node = node(%Q{<message>hello!</message>})
    stanza = Vines::Stanza::Message.new(node, @stream)
    assert_nil stanza.validate_to
    assert_nil stanza.validate_from
    assert @stream.verify
  end

  def test_validate_valid_addresses
    node = node(%Q{<message from="#{@alice}" to="#{@romeo}">hello!</message>})
    stanza = Vines::Stanza::Message.new(node, @stream)
    assert_equal @romeo, stanza.validate_to
    assert_equal @alice, stanza.validate_from
    assert @stream.verify
  end

  def test_validate_invalid_addresses
    node = node(%Q{<message from="a lice@wonderland.lit" to="romeo@v erona.lit">hello!</message>})
    stanza = Vines::Stanza::Message.new(node, @stream)
    assert_raises(Vines::StanzaErrors::JidMalformed) { stanza.validate_to }
    assert_raises(Vines::StanzaErrors::JidMalformed) { stanza.validate_from }
    assert @stream.verify
  end

  def test_non_routable_stanza_is_local
    stanza = Vines::Stanza.new(node('<auth/>'), @stream)
    assert stanza.local?
    assert @stream.verify
  end

  def test_stanza_missing_to_is_local
    node = node(%Q{<message>hello!</message>})
    stanza = Vines::Stanza::Message.new(node, @stream)
    assert stanza.local?
    assert @stream.verify
  end

  def test_stanza_with_local_jid_is_local
    node = node(%Q{<message to="#{@alice}">hello!</message>})
    @stream.expect(:config, @config)
    stanza = Vines::Stanza::Message.new(node, @stream)
    assert stanza.local?
    assert @stream.verify
  end

  def test_stanza_with_remote_jid_is_not_local
    node = node(%Q{<message to="#{@romeo}">hello!</message>})
    @stream.expect(:config, @config)
    stanza = Vines::Stanza::Message.new(node, @stream)
    refute stanza.local?
    assert @stream.verify
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
