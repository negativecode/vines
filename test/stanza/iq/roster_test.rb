# encoding: UTF-8

require 'test_helper'

describe Vines::Stanza::Iq::Roster do
  subject      { Vines::Stanza::Iq::Roster.new(xml, stream) }
  let(:stream) { MiniTest::Mock.new }
# FIXME try without resource
  let(:alice)  { Vines::User.new(jid: 'alice@wonderland.lit/tea') }

  before do
    class << stream
      attr_accessor :domain, :user
    end
    stream.user = alice
    stream.domain = 'wonderland.lit'
  end

  describe 'when retrieving an empty roster' do
    let(:xml) { node(%q{<iq id="42" type="get"><query xmlns='jabber:iq:roster'/></iq>}) }
    let(:expected) { node(%q{<iq id="42" type="result"><query xmlns="jabber:iq:roster"/></iq>}) }

    before do
      stream.expect :write, nil, [expected]
      stream.expect :requested_roster!, nil
    end

    it 'returns an empty stanza' do
      subject.process
      stream.verify
    end
  end

  describe 'when retrieving a non-empty roster' do
    let(:xml) { node(%q{<iq id="42" type="get"><query xmlns='jabber:iq:roster'/></iq>}) }
    let(:expected) do
      node(%q{
        <iq id="42" type="result">
          <query xmlns="jabber:iq:roster">
            <item jid="cat@wonderland.lit" subscription="none">
              <group>Cats</group>
              <group>Friends</group>
            </item>
            <item jid="hatter@wonderland.lit" subscription="none"/>
          </query>
        </iq>})
    end

    before do
      alice.roster << Vines::Contact.new(jid: 'hatter@wonderland.lit')
      alice.roster << Vines::Contact.new(jid: 'cat@wonderland.lit', :groups => ['Friends', 'Cats'])

      stream.expect :write, nil, [expected]
      stream.expect :requested_roster!, nil
    end

    it 'sorts groups alphabetically' do
      subject.process
      stream.verify
    end
  end

  describe 'when requesting a roster for another user' do
    let(:xml) do
      node(%q{
        <iq id="42" type="get" to="romeo@verona.lit">
          <query xmlns="jabber:iq:roster"/>
        </iq>})
    end

    it 'raises a forbidden stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::Forbidden
      stream.verify
    end
  end

  describe 'when saving a roster for another user' do
    let(:xml) do
      node(%q{
        <iq id="42" type="set" to="romeo@verona.lit">
          <query xmlns="jabber:iq:roster"/>
        </iq>})
    end

    it 'raises a forbidden stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::Forbidden
      stream.verify
    end
  end

  describe 'when saving a roster with no items' do
    let(:xml) do
      node(%q{
        <iq id="42" type="set">
          <query xmlns="jabber:iq:roster"/>
        </iq>})
    end

    it 'raises a bad-request stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::BadRequest
      stream.verify
    end
  end

  describe 'when updating a roster with more than one item' do
    let(:xml) do
      node(%q{
        <iq id="42" type="set">
          <query xmlns="jabber:iq:roster">
            <item jid="hatter@wonderland.lit"/>
            <item jid="cat@wonderland.lit"/>
          </query>
        </iq>})
    end

    it 'raises a bad-request stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::BadRequest
      stream.verify
    end
  end

  describe 'when adding a roster item without a jid attribute' do
    let(:xml) do
      node(%q{
        <iq id="42" type="set">
          <query xmlns="jabber:iq:roster">
            <item name="Mad Hatter"/>
          </query>
        </iq>})
    end

    it 'raises a bad-request stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::BadRequest
      stream.verify
    end
  end

  describe 'when adding a roster item with duplicate groups' do
    let(:xml) do
      node(%q{
        <iq id="42" type="set">
          <query xmlns="jabber:iq:roster">
            <item jid="hatter@wonderland.lit" name="Mad Hatter">
              <group>Friends</group>
              <group>Friends</group>
            </item>
          </query>
        </iq>})
    end

    it 'raises a bad-request stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::BadRequest
      stream.verify
    end
  end

  describe 'when adding a roster item with an empty group name' do
    let(:xml) do
      node(%q{
        <iq id="42" type="set">
          <query xmlns="jabber:iq:roster">
            <item jid="hatter@wonderland.lit" name="Mad Hatter">
              <group></group>
            </item>
          </query>
        </iq>})
    end

    it 'raises a not-acceptable stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::NotAcceptable
      stream.verify
    end
  end

  describe 'when saving a roster successfully' do
    let(:xml) do
      node(%q{
        <iq id="42" type="set">
          <query xmlns="jabber:iq:roster">
            <item jid="hatter@wonderland.lit" name="Mad Hatter">
              <group>Friends</group>
            </item>
          </query>
        </iq>})
    end

    let(:expected) do
      node(%q{
        <iq to="alice@wonderland.lit/tea" type="set">
          <query xmlns="jabber:iq:roster">
            <item jid="hatter@wonderland.lit" name="Mad Hatter" subscription="none">
              <group>Friends</group>
            </item>
          </query>
        </iq>})
    end

    let(:storage) { MiniTest::Mock.new }
    let(:recipient) { MiniTest::Mock.new }
    let(:result) { node(%Q{<iq id="42" to="#{alice.jid}" type="result"/>}) }

    before do
      storage.expect :save_user, nil, [alice]

      recipient.expect :user, alice
      def recipient.nodes; @nodes; end
      def recipient.write(node)
        @nodes ||= []
        @nodes << node
      end

      stream.expect :interested_resources, [recipient], [alice.jid]
      stream.expect :update_user_streams, nil, [alice]
      stream.expect :storage, storage, ['wonderland.lit']
      stream.expect :write, nil, [result]
    end

    it 'sends a result to the sender' do
      subject.process
      stream.verify
      storage.verify
    end

    it 'sends the new roster item to the interested streams' do
      subject.process
      recipient.nodes.first.remove_attribute('id') # id is random
      recipient.nodes.first.must_equal expected
    end
  end
end
