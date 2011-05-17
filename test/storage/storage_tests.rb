# encoding: UTF-8

require 'vines'
require 'ext/nokogiri'
require 'test/unit'

# Mixin methods for storage implementation test classes. The behavioral
# tests are the same regardless of implementation so share those methods
# here.
module StorageTests
  VCARD = Nokogiri::XML(%q{
    <vCard xmlns="vcard-temp">
      <FN>Alice in Wonderland</FN>
    </vCard>
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
end
