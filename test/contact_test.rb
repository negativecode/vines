# encoding: UTF-8

require 'vines'
require 'ext/nokogiri'
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

  def test_send_roster_push
    contact = Vines::Contact.new(
      :jid => 'alice@wonderland.lit',
      :name => "Alice",
      :groups => %w[Friends Buddies],
      :subscription => 'from')

    recipient = MiniTest::Mock.new
    recipient.expect(:user, Vines::User.new(:jid => 'hatter@wonderland.lit'))
    def recipient.nodes; @nodes; end
    def recipient.write(node)
      @nodes ||= []
      @nodes << node
    end

    contact.send_roster_push(recipient)
    assert recipient.verify
    assert_equal 1, recipient.nodes.size

    expected = node(%q{
      <iq to="hatter@wonderland.lit" type="set">
        <query xmlns="jabber:iq:roster">
        <item jid="alice@wonderland.lit" name="Alice" subscription="from">
          <group>Buddies</group>
          <group>Friends</group>
        </item>
        </query>
      </iq>
    }.strip.gsub(/\n/, '').gsub(/\s{2,}/, ''))
    recipient.nodes[0].remove_attribute('id') # id is random
    assert_equal expected, recipient.nodes[0]
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
