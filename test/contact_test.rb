# encoding: UTF-8

require 'vines'
require 'minitest/autorun'

class ContactTest < MiniTest::Unit::TestCase
  def test_equality
    alice  = Vines::Contact.new(:jid => 'alice@wonderland.lit')
    alice2 = Vines::Contact.new(:jid => 'alice@wonderland.lit')
    hatter = Vines::Contact.new(:jid => 'hatter@wonderland.lit')

    assert_nil alice <=> 42

    assert alice == alice2
    assert alice.eql?(alice2)
    assert alice.hash == alice2.hash

    refute alice == hatter
    refute alice.eql?(hatter)
    refute alice.hash == hatter.hash
  end

  def test_initialize_missing_jid
    assert_raises(ArgumentError) { Vines::Contact.new }
  end

  def test_to_roster_xml_sorts_groups
    contact = Vines::Contact.new(
      :jid => 'a@wonderland.lit',
      :name => "Contact 1",
      :groups => %w[B A])

    expected = %q{
      <item jid="a@wonderland.lit" name="Contact 1" subscription="none">
        <group>A</group>
        <group>B</group>
      </item>
    }.strip.gsub(/\n/, '').gsub(/\s{2,}/, '')

    assert_equal expected, contact.to_roster_xml.to_xml(:indent => 0).gsub(/\n/, '')
  end
end
