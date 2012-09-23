# encoding: UTF-8

require 'test_helper'

describe Vines::User do
  subject { Vines::User.new(jid: 'alice@wonderland.lit', name: 'Alice', password: 'secr3t') }

  describe 'user equality checks' do
    let(:alice)  { Vines::User.new(jid: 'alice@wonderland.lit') }
    let(:hatter) { Vines::User.new(jid: 'hatter@wonderland.lit') }

    it 'uses class in equality check' do
      (subject <=> 42).must_be_nil
    end

    it 'is equal to itself' do
      assert subject == subject
      assert subject.eql?(subject)
      assert subject.hash == subject.hash
    end

    it 'is equal to another user with the same jid' do
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
      -> { Vines::User.new }.must_raise ArgumentError
      -> { Vines::User.new(jid: '') }.must_raise ArgumentError
    end

    it 'has an empty roster' do
      subject.roster.wont_be_nil
      subject.roster.size.must_equal 0
    end
  end

  describe '#update_from' do
    let(:updated) { Vines::User.new(jid: 'alice2@wonderland.lit', name: 'Alice 2', password: "secr3t 2") }

    before do
      subject.roster << Vines::Contact.new(jid: 'hatter@wonderland.lit', name: "Hatter")
      updated.roster << Vines::Contact.new(jid: 'cat@wonderland.lit', name: "Cheshire")
    end

    it 'updates jid, name, and password' do
      subject.update_from(updated)
      subject.jid.to_s.must_equal 'alice@wonderland.lit'
      subject.name.must_equal 'Alice 2'
      subject.password.must_equal 'secr3t 2'
    end

    it 'overwrites the entire roster' do
      subject.update_from(updated)
      subject.roster.size.must_equal 1
      subject.roster.first.must_equal updated.roster.first
    end

    it 'clones roster entries' do
      subject.update_from(updated)
      updated.roster.first.name = 'Updated Contact 2'
      subject.roster.first.name.must_equal 'Cheshire'
    end
  end

  describe '#to_roster_xml' do
    let(:expected) do
      node(%q{
        <iq id="42" type="result">
          <query xmlns="jabber:iq:roster">
            <item jid="a@wonderland.lit" name="Contact 1" subscription="none"><group>A</group><group>B</group></item>
            <item jid="b@wonderland.lit" name="Contact 2" subscription="none"><group>C</group></item>
          </query>
        </iq>
      })
    end

    before do
      subject.roster << Vines::Contact.new(jid: 'b@wonderland.lit', name: "Contact 2", groups: %w[C])
      subject.roster << Vines::Contact.new(jid: 'a@wonderland.lit', name: "Contact 1", groups: %w[B A])
    end

    it 'sorts group names' do
      subject.to_roster_xml(42).must_equal expected
    end
  end
end
