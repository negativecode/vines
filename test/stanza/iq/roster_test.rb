# encoding: UTF-8

require 'vines'
require 'ext/nokogiri'
require 'minitest/autorun'

class RosterTest < MiniTest::Unit::TestCase
  def setup
    @stream = MiniTest::Mock.new
  end

  def test_roster_get_with_empty_roster
    alice = Vines::User.new(:jid => 'alice@wonderland.lit')
    expected = node(%q{<iq id="42" type="result"><query xmlns="jabber:iq:roster"/></iq>})
    @stream.expect(:write, nil, [expected])
    @stream.expect(:requested_roster!, nil)
    @stream.expect(:user, alice)

    node = node(%q{<iq id="42" type="get"><query xmlns='jabber:iq:roster'/></iq>})
    stanza = Vines::Stanza::Iq::Roster.new(node, @stream)
    stanza.process
    assert @stream.verify
  end

  def test_roster_get_with_non_empty_roster
    alice = Vines::User.new(:jid => 'alice@wonderland.lit')
    alice.roster << Vines::Contact.new(:jid => 'hatter@wonderland.lit')
    alice.roster << Vines::Contact.new(:jid => 'cat@wonderland.lit', :groups => ['Friends', 'Cats'])

    expected = node(%q{
      <iq id="42" type="result">
        <query xmlns="jabber:iq:roster">
          <item jid="cat@wonderland.lit" subscription="none">
            <group>Cats</group>
            <group>Friends</group>
          </item>
          <item jid="hatter@wonderland.lit" subscription="none"/>
        </query>
      </iq>}.strip.gsub(/\n|\s{2,}/, ''))

    @stream.expect(:write, nil, [expected])
    @stream.expect(:requested_roster!, nil)
    @stream.expect(:user, alice)

    node = node(%q{<iq id="42" type="get"><query xmlns='jabber:iq:roster'/></iq>})
    stanza = Vines::Stanza::Iq::Roster.new(node, @stream)
    stanza.process
    assert @stream.verify
  end

  def test_roster_set_with_invalid_to_address
    alice = Vines::User.new(:jid => 'alice@wonderland.lit/tea')
    @stream.expect(:user, alice)

    node = node(%q{
      <iq id="42" type="set" to="romeo@verona.lit">
        <query xmlns="jabber:iq:roster"/>
      </iq>}.strip.gsub(/\n|\s{2,}/, ''))

    stanza = Vines::Stanza::Iq::Roster.new(node, @stream)
    assert_raises(Vines::StanzaErrors::Forbidden) { stanza.process }
    assert @stream.verify
  end

  def test_roster_set_with_no_items
    node = node(%q{
      <iq id="42" type="set">
        <query xmlns="jabber:iq:roster"/>
      </iq>}.strip.gsub(/\n|\s{2,}/, ''))

    stanza = Vines::Stanza::Iq::Roster.new(node, @stream)
    assert_raises(Vines::StanzaErrors::BadRequest) { stanza.process }
    assert @stream.verify
  end

  def test_roster_set_with_two_items
    node = node(%q{
      <iq id="42" type="set">
        <query xmlns="jabber:iq:roster">
          <item jid="hatter@wonderland.lit"/>
          <item jid="cat@wonderland.lit"/>
        </query>
      </iq>}.strip.gsub(/\n|\s{2,}/, ''))

    stanza = Vines::Stanza::Iq::Roster.new(node, @stream)
    assert_raises(Vines::StanzaErrors::BadRequest) { stanza.process }
    assert @stream.verify
  end

  def test_roster_set_missing_jid
    node = node(%q{
      <iq id="42" type="set">
        <query xmlns="jabber:iq:roster">
          <item name="Mad Hatter"/>
        </query>
      </iq>}.strip.gsub(/\n|\s{2,}/, ''))

    stanza = Vines::Stanza::Iq::Roster.new(node, @stream)
    assert_raises(Vines::StanzaErrors::BadRequest) { stanza.process }
    assert @stream.verify
  end

  def test_roster_set_with_duplicate_groups
    alice = Vines::User.new(:jid => 'alice@wonderland.lit/tea')
    @stream.expect(:user, alice)

    node = node(%q{
      <iq id="42" type="set">
        <query xmlns="jabber:iq:roster">
          <item jid="hatter@wonderland.lit" name="Mad Hatter">
            <group>Friends</group>
            <group>Friends</group>
          </item>
        </query>
      </iq>}.strip.gsub(/\n|\s{2,}/, ''))

    stanza = Vines::Stanza::Iq::Roster.new(node, @stream)
    assert_raises(Vines::StanzaErrors::BadRequest) { stanza.process }
    assert @stream.verify
  end

  def test_roster_set_with_empty_group
    alice = Vines::User.new(:jid => 'alice@wonderland.lit/tea')
    @stream.expect(:user, alice)

    node = node(%q{
      <iq id="42" type="set">
        <query xmlns="jabber:iq:roster">
          <item jid="hatter@wonderland.lit" name="Mad Hatter">
            <group></group>
          </item>
        </query>
      </iq>}.strip.gsub(/\n|\s{2,}/, ''))

    stanza = Vines::Stanza::Iq::Roster.new(node, @stream)
    assert_raises(Vines::StanzaErrors::NotAcceptable) { stanza.process }
    assert @stream.verify
  end

  def test_roster_set_sends_results
    alice = Vines::User.new(:jid => 'alice@wonderland.lit/tea')
    storage = MiniTest::Mock.new
    storage.expect(:save_user, nil, [alice])

    recipient = MiniTest::Mock.new
    recipient.expect(:user, alice)
    def recipient.nodes; @nodes; end
    def recipient.write(node)
      @nodes ||= []
      @nodes << node
    end

    router = MiniTest::Mock.new
    router.expect(:interested_resources, [recipient], [alice.jid])

    @stream.expect(:user, alice)
    @stream.expect(:update_user_streams, nil, [alice])
    @stream.expect(:router, router)
    @stream.expect(:domain, 'wonderland.lit')
    @stream.expect(:storage, storage, ['wonderland.lit'])
    expected = node(%q{<iq id="42" type="result"/>})
    @stream.expect(:write, nil, [expected])

    node = node(%q{
      <iq id="42" type="set">
        <query xmlns="jabber:iq:roster">
          <item jid="hatter@wonderland.lit" name="Mad Hatter">
            <group>Friends</group>
          </item>
        </query>
      </iq>}.strip.gsub(/\n|\s{2,}/, ''))

    stanza = Vines::Stanza::Iq::Roster.new(node, @stream)
    stanza.process
    assert @stream.verify
    assert storage.verify
    assert router.verify

    expected = node(%q{
      <iq type="set" to="alice@wonderland.lit/tea">
        <query xmlns="jabber:iq:roster">
          <item jid="hatter@wonderland.lit" name="Mad Hatter" subscription="none">
            <group>Friends</group>
          </item>
        </query>
      </iq>}.strip.gsub(/\n|\s{2,}/, ''))
    recipient.nodes[0].remove_attribute('id') # id is random
    assert_equal expected, recipient.nodes[0]
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
