# encoding: UTF-8

require 'vines'
require 'ext/nokogiri'
require 'minitest/autorun'

class VcardTest < MiniTest::Unit::TestCase
  def setup
    @stream = MiniTest::Mock.new
    @config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir '.' }
      end
    end
  end

  def test_vcard_get_on_remote_jid_routes
    alice = Vines::User.new(:jid => 'alice@wonderland.lit/tea')
    node = node(%q{<iq id="42" to="romeo@verona.lit" type="get"><vCard xmlns="vcard-temp"/></iq>})

    router = MiniTest::Mock.new
    router.expect(:route, nil, [node])

    @stream.expect(:config, @config)
    @stream.expect(:user, alice)
    @stream.expect(:router, router)

    stanza = Vines::Stanza::Iq::Vcard.new(node, @stream)
    stanza.process
    assert @stream.verify
    assert router.verify
  end

  def test_vcard_get_missing_to_address
    alice = Vines::User.new(:jid => 'alice@wonderland.lit/tea')
    node = node(%q{<iq id="42" type="get"><vCard xmlns="vcard-temp"/></iq>})

    card = node(%q{<vCard xmlns="vcard-temp"><FN>Alice in Wonderland</FN></vCard>})

    storage = MiniTest::Mock.new
    storage.expect(:find_vcard, card, [alice.jid.bare])

    @stream.expect(:user, alice)
    @stream.expect(:domain, 'wonderland.lit')
    @stream.expect(:storage, storage, ['wonderland.lit'])
    expected = node(%q{
      <iq id="42" to="alice@wonderland.lit/tea" type="result">
        <vCard xmlns="vcard-temp">
          <FN>Alice in Wonderland</FN>
        </vCard>
      </iq>}.strip.gsub(/\n|\s{2,}/, ''))
    @stream.expect(:write, nil, [expected])

    stanza = Vines::Stanza::Iq::Vcard.new(node, @stream)
    stanza.process
    assert @stream.verify
    assert storage.verify
  end

  def test_vcard_get_another_user_includes_from_address
    alice = Vines::User.new(:jid => 'alice@wonderland.lit/tea')
    node = node(%q{<iq id="42" to="hatter@wonderland.lit" type="get"><vCard xmlns="vcard-temp"/></iq>})

    card = node(%q{<vCard xmlns="vcard-temp"><FN>Mad Hatter</FN></vCard>})

    storage = MiniTest::Mock.new
    storage.expect(:find_vcard, card, [Vines::JID.new('hatter@wonderland.lit')])

    @stream.expect(:config, @config)
    @stream.expect(:user, alice)
    @stream.expect(:domain, 'wonderland.lit')
    @stream.expect(:storage, storage, ['wonderland.lit'])
    expected = node(%q{
      <iq from="hatter@wonderland.lit" id="42" to="alice@wonderland.lit/tea" type="result">
        <vCard xmlns="vcard-temp">
          <FN>Mad Hatter</FN>
        </vCard>
      </iq>}.strip.gsub(/\n|\s{2,}/, ''))
    @stream.expect(:write, nil, [expected])

    stanza = Vines::Stanza::Iq::Vcard.new(node, @stream)
    stanza.process
    assert @stream.verify
    assert storage.verify
  end

  def test_missing_vcard_get_returns_item_not_found
    alice = Vines::User.new(:jid => 'alice@wonderland.lit/tea')
    node = node(%q{<iq id="42" type="get"><vCard xmlns="vcard-temp"/></iq>})

    storage = MiniTest::Mock.new
    storage.expect(:find_vcard, nil, [alice.jid.bare])

    @stream.expect(:user, alice)
    @stream.expect(:domain, 'wonderland.lit')
    @stream.expect(:storage, storage, ['wonderland.lit'])

    stanza = Vines::Stanza::Iq::Vcard.new(node, @stream)
    assert_raises(Vines::StanzaErrors::ItemNotFound) { stanza.process }
    assert @stream.verify
    assert storage.verify
  end

  def test_vcard_set_on_another_user_returns_forbidden
    alice = Vines::User.new(:jid => 'alice@wonderland.lit/tea')
    node = node(%q{<iq id="42" to="hatter@wonderland.lit" type="set"><vCard xmlns="vcard-temp"><FN>Alice</FN></vCard></iq>})

    @stream.expect(:config, @config)
    @stream.expect(:user, alice)

    stanza = Vines::Stanza::Iq::Vcard.new(node, @stream)
    assert_raises(Vines::StanzaErrors::Forbidden) { stanza.process }
    assert @stream.verify
  end

  def test_vcard_set_returns_result
    alice = Vines::User.new(:jid => 'alice@wonderland.lit/tea')
    node = node(%q{<iq id="42" type="set"><vCard xmlns="vcard-temp"><FN>Alice</FN></vCard></iq>})
    card = node(%q{<vCard xmlns="vcard-temp"><FN>Alice</FN></vCard>})

    storage = MiniTest::Mock.new
    storage.expect(:save_vcard, nil, [alice.jid, card])

    @stream.expect(:user, alice)
    @stream.expect(:domain, 'wonderland.lit')
    @stream.expect(:storage, storage, ['wonderland.lit'])
    expected = node(%q{<iq id="42" to="alice@wonderland.lit/tea" type="result"/>})
    @stream.expect(:write, nil, [expected])

    stanza = Vines::Stanza::Iq::Vcard.new(node, @stream)
    stanza.process
    assert @stream.verify
    assert storage.verify
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
