# encoding: UTF-8

require 'test_helper'

describe Vines::Contact do
  subject do
    Vines::Contact.new(
      jid: 'alice@wonderland.lit',
      name: "Alice",
      groups: %w[Friends Buddies],
      subscription: 'from')
  end

  describe 'contact equality checks' do
    let(:alice)  { Vines::Contact.new(jid: 'alice@wonderland.lit') }
    let(:hatter) { Vines::Contact.new(jid: 'hatter@wonderland.lit') }

    it 'uses class in equality check' do
      (subject <=> 42).must_be_nil
    end

    it 'is equal to itself' do
      assert subject == subject
      assert subject.eql?(subject)
      assert subject.hash == subject.hash
    end

    it 'is equal to another contact with the same jid' do
      assert subject == alice
      assert subject.eql?(alice)
      assert subject.hash == alice.hash
    end

    it 'is not equal to a different jid' do
      refute subject == hatter
      refute subject.eql?(hatter)
      refute subject.hash == hatter.hash
    end
  end

  describe 'initialize' do
    it 'raises when not given a jid' do
      -> { Vines::Contact.new }.must_raise ArgumentError
      -> { Vines::Contact.new(jid: '') }.must_raise ArgumentError
    end

    it 'accepts a domain-only jid' do
      contact = Vines::Contact.new(jid: 'tea.wonderland.lit')
      contact.jid.to_s.must_equal 'tea.wonderland.lit'
    end
  end

  describe '#to_roster_xml' do
    let(:expected) do
      node(%q{
        <item jid="alice@wonderland.lit" name="Alice" subscription="from">
          <group>Buddies</group>
          <group>Friends</group>
        </item>
      })
    end

    it 'sorts group names' do
      subject.to_roster_xml.must_equal expected
    end
  end

  describe '#send_roster_push' do
    let(:recipient) { MiniTest::Mock.new }
    let(:expected) do
      node(%q{
        <iq to="hatter@wonderland.lit" type="set">
          <query xmlns="jabber:iq:roster">
          <item jid="alice@wonderland.lit" name="Alice" subscription="from">
            <group>Buddies</group>
            <group>Friends</group>
          </item>
          </query>
        </iq>
      })
    end

    before do
      recipient.expect :user, Vines::User.new(jid: 'hatter@wonderland.lit')
      class << recipient
        attr_accessor :nodes
        def write(node)
          @nodes ||= []
          @nodes << node
        end
      end
    end

    it '' do
      subject.send_roster_push(recipient)
      recipient.verify
      recipient.nodes.size.must_equal 1
      recipient.nodes.first.remove_attribute('id') # id is random
      recipient.nodes.first.must_equal expected
    end
  end
end
