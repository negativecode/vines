# encoding: UTF-8

require 'vines'
require 'minitest/autorun'

class UserTest < MiniTest::Unit::TestCase
  def test_equality
    alice  = Vines::User.new(:jid => 'alice@wonderland.lit')
    alice2 = Vines::User.new(:jid => 'alice@wonderland.lit')
    hatter = Vines::User.new(:jid => 'hatter@wonderland.lit')

    assert_nil alice <=> 42

    assert alice == alice2
    assert alice.eql?(alice2)
    assert alice.hash == alice2.hash

    refute alice == hatter
    refute alice.eql?(hatter)
    refute alice.hash == hatter.hash
  end

  def test_initialize_missing_jid
    assert_raises(ArgumentError) { Vines::User.new }
  end

  def test_initialize_missing_roster
    user = Vines::User.new(:jid => 'alice@wonderland.lit')
    refute_nil user.roster
    assert_equal 0, user.roster.size
  end

  def test_update_from
    user = Vines::User.new(:jid => 'alice@wonderland.lit', :name => 'Alice', :password => "secr3t")
    user.roster << Vines::Contact.new(:jid => 'hatter@wonderland.lit', :name => "Hatter")

    updated = Vines::User.new(:jid => 'alice2@wonderland.lit', :name => 'Alice 2', :password => "secr3t 2")
    updated.roster << Vines::Contact.new(:jid => 'cat@wonderland.lit', :name => "Cheshire")

    user.update_from(updated)
    assert_equal 'alice@wonderland.lit', user.jid.to_s
    assert_equal 'Alice 2', user.name
    assert_equal 'secr3t 2', user.password
    assert_equal 1, user.roster.size
    assert_equal Vines::Contact.new(:jid => 'cat@wonderland.lit'), user.roster.first
    # make sure we cloned roster entries
    updated.roster.first.name = 'Updated Contact 2'
    assert_equal 'Cheshire', user.roster.first.name
  end

  def test_to_roster_xml_contacts_and_groups_are_sorted
    user = Vines::User.new(:jid => 'alice@wonderland.lit', :name => 'Alice', :password => "secr3t")
    user.roster << Vines::Contact.new(:jid => 'b@wonderland.lit', :name => "Contact 2", :groups => %w[C])
    user.roster << Vines::Contact.new(:jid => 'a@wonderland.lit', :name => "Contact 1", :groups => %w[B A])

    expected = %q{
      <iq id="42" type="result">
        <query xmlns="jabber:iq:roster">
          <item jid="a@wonderland.lit" name="Contact 1" subscription="none"><group>A</group><group>B</group></item>
          <item jid="b@wonderland.lit" name="Contact 2" subscription="none"><group>C</group></item>
        </query>
      </iq>}.strip.gsub(/\n/, '').gsub(/\s{2,}/, '')

    assert_equal expected, user.to_roster_xml(42).to_xml(:indent => 0).gsub(/\n/, '')
  end
end
