# encoding: UTF-8

require 'test_helper'

# Mixin methods for storage implementation test classes. The behavioral
# tests are the same regardless of implementation so share those methods
# here.
module StorageTests
  FRAGMENT_ID = Digest::SHA1.hexdigest("characters:urn:wonderland")

  FRAGMENT = Nokogiri::XML(%q{
    <characters xmlns="urn:wonderland">
      <character>Alice</character>
    </characters>
  }.strip).root

  VCARD = Nokogiri::XML(%q{
    <vCard xmlns="vcard-temp">
      <FN>Alice in Wonderland</FN>
    </vCard>
  }.strip).root

  MESSAGE = Nokogiri::XML(%q{
    <message type='chat' id='purple70c423f7' from='full@wonderland.lit/resource' to='offline_user@domain.tld/resource'>
      <active xmlns='http://jabber.org/protocol/chatstates'/>
      <body>Foo</body>
    </message
  }.strip).root

  class EMLoop
    def initialize
      EM.run do
        Fiber.new do
          yield
          EM.stop
        end.resume
      end
    end
  end

  def test_authenticate
    EMLoop.new do
      db = storage
      assert_nil db.authenticate(nil, nil)
      assert_nil db.authenticate(nil, 'secret')
      assert_nil db.authenticate('bogus', nil)
      assert_nil db.authenticate('bogus', 'secret')
      assert_nil db.authenticate('empty@wonderland.lit', 'secret')
      assert_nil db.authenticate('no_password@wonderland.lit', 'secret')
      assert_nil db.authenticate('clear_password@wonderland.lit', 'secret')

      user = db.authenticate('bcrypt_password@wonderland.lit', 'secret')
      refute_nil user
      assert_equal('bcrypt_password@wonderland.lit', user.jid.to_s)

      user = db.authenticate('full@wonderland.lit', 'secret')
      refute_nil user
      assert_equal 'Tester', user.name
      assert_equal 'full@wonderland.lit', user.jid.to_s

      assert_equal 2, user.roster.length
      assert_equal 'contact1@wonderland.lit', user.roster[0].jid.to_s
      assert_equal 'Contact1', user.roster[0].name
      assert_equal 2, user.roster[0].groups.length
      assert_equal 'Group1', user.roster[0].groups[0]
      assert_equal 'Group2', user.roster[0].groups[1]

      assert_equal 'contact2@wonderland.lit', user.roster[1].jid.to_s
      assert_equal 'Contact2', user.roster[1].name
      assert_equal 2, user.roster[1].groups.length
      assert_equal 'Group3', user.roster[1].groups[0]
      assert_equal 'Group4', user.roster[1].groups[1]
    end
  end

  def test_find_user
    EMLoop.new do
      db = storage
      user = db.find_user(nil)
      assert_nil user

      user = db.find_user('full@wonderland.lit')
      refute_nil user
      assert_equal 'full@wonderland.lit', user.jid.to_s

      user = db.find_user(Vines::JID.new('full@wonderland.lit'))
      refute_nil user
      assert_equal 'full@wonderland.lit', user.jid.to_s

      user = db.find_user(Vines::JID.new('full@wonderland.lit/resource'))
      refute_nil user
      assert_equal 'full@wonderland.lit', user.jid.to_s
    end
  end

  def test_save_user
    EMLoop.new do
      db = storage
      user = Vines::User.new(
        :jid => 'save_user@domain.tld/resource1',
        :name => 'Save User',
        :password => 'secret')
      user.roster << Vines::Contact.new(
        :jid => 'contact1@domain.tld/resource2',
        :name => 'Contact 1')
      db.save_user(user)
      user = db.find_user('save_user@domain.tld')
      refute_nil user
      assert_equal 'save_user@domain.tld', user.jid.to_s
      assert_equal 'Save User', user.name
      assert_equal 1, user.roster.length
      assert_equal 'contact1@domain.tld', user.roster[0].jid.to_s
      assert_equal 'Contact 1', user.roster[0].name
    end
  end

  def test_find_vcard
    EMLoop.new do
      db = storage
      card = db.find_vcard(nil)
      assert_nil card

      card = db.find_vcard('full@wonderland.lit')
      refute_nil card
      assert_equal VCARD, card

      card = db.find_vcard(Vines::JID.new('full@wonderland.lit'))
      refute_nil card
      assert_equal VCARD, card

      card = db.find_vcard(Vines::JID.new('full@wonderland.lit/resource'))
      refute_nil card
      assert_equal VCARD, card
    end
  end

  def test_save_vcard
    EMLoop.new do
      db = storage
      db.save_user(Vines::User.new(:jid => 'save_user@domain.tld'))
      db.save_vcard('save_user@domain.tld/resource1', VCARD)
      card = db.find_vcard('save_user@domain.tld')
      refute_nil card
      assert_equal VCARD, card
    end
  end

  def test_find_fragment
    EMLoop.new do
      db = storage
      root = Nokogiri::XML(%q{<characters xmlns="urn:wonderland"/>}).root
      bad_name = Nokogiri::XML(%q{<not_characters xmlns="urn:wonderland"/>}).root
      bad_ns = Nokogiri::XML(%q{<characters xmlns="not:wonderland"/>}).root

      node = db.find_fragment(nil, nil)
      assert_nil node

      node = db.find_fragment('full@wonderland.lit', bad_name)
      assert_nil node

      node = db.find_fragment('full@wonderland.lit', bad_ns)
      assert_nil node

      node = db.find_fragment('full@wonderland.lit', root)
      refute_nil node
      assert_equal FRAGMENT, node

      node = db.find_fragment(Vines::JID.new('full@wonderland.lit'), root)
      refute_nil node
      assert_equal FRAGMENT, node

      node = db.find_fragment(Vines::JID.new('full@wonderland.lit/resource'), root)
      refute_nil node
      assert_equal FRAGMENT, node
    end
  end

  def test_save_fragment
    EMLoop.new do
      db = storage
      root = Nokogiri::XML(%q{<characters xmlns="urn:wonderland"/>}).root
      db.save_user(Vines::User.new(:jid => 'save_user@domain.tld'))
      db.save_fragment('save_user@domain.tld/resource1', FRAGMENT)
      node = db.find_fragment('save_user@domain.tld', root)
      refute_nil node
      assert_equal FRAGMENT, node
    end
  end

  def test_delay_message
    EMLoop.new do
      db = storage
      db.save_user(Vines::User.new(:jid => 'offline_user@domain.tld'))
      db.delay_message('offline_user@domain.tld/resource', MESSAGE)
      messages = db.fetch_delayed_messages('offline_user@domain.tld')
      refute_nil messages
      assert_equal messages.count, 1
      message = messages[0]
      assert_equal MESSAGE['id'], message['id']
      # Test if messages had been removed
      messages = db.fetch_delayed_messages('offline_user@domain.tld')
      assert_equal messages, []
    end
  end
end
