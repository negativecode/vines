# encoding: UTF-8

require 'storage_tests'
require 'vines'
require 'minitest/autorun'

class StorageTest < MiniTest::Unit::TestCase
  ALICE = 'alice@wonderland.lit'.freeze

  class MockLdapStorage < Vines::Storage
    attr_reader :authenticate_calls, :find_user_calls, :save_user_calls

    def initialize(found_user=nil)
      @found_user = found_user
      @authenticate_calls = @find_user_calls = @save_user_calls = 0
      @ldap = MiniTest::Mock.new
    end

    def authenticate(username, password)
      @authenticate_calls += 1
      nil
    end
    wrap_ldap :authenticate

    def find_user(jid)
      @find_user_calls += 1
      @found_user
    end

    def save_user(user)
      @save_user_calls += 1
    end
  end

  def test_authenticate_with_ldap_missing_password
    StorageTests::EMLoop.new do
      storage = MockLdapStorage.new
      user = storage.authenticate(ALICE, '')
      assert_nil user
      assert_equal 0, storage.authenticate_calls
      assert_equal 0, storage.find_user_calls
      assert_equal 0, storage.save_user_calls
      assert storage.ldap.verify
    end
  end

  def test_authenticate_with_ldap_bad_password
    StorageTests::EMLoop.new do
      storage = MockLdapStorage.new
      storage.ldap.expect(:authenticate, nil, [ALICE, 'bogus'])
      user = storage.authenticate(ALICE, 'bogus')
      assert_nil user
      assert_equal 0, storage.authenticate_calls
      assert_equal 0, storage.find_user_calls
      assert_equal 0, storage.save_user_calls
      assert storage.ldap.verify
    end
  end

  def test_authenticate_with_ldap_user_exists_in_database
    StorageTests::EMLoop.new do
      alice = Vines::User.new(:jid => ALICE)
      storage = MockLdapStorage.new(alice)
      storage.ldap.expect(:authenticate, alice, [ALICE, 'secr3t'])
      user = storage.authenticate(ALICE, 'secr3t')
      refute_nil user
      assert_equal ALICE, user.jid.to_s
      assert_equal 0, storage.authenticate_calls
      assert_equal 1, storage.find_user_calls
      assert_equal 0, storage.save_user_calls
      assert storage.ldap.verify
    end
  end

  def test_authenticate_with_ldap_save_user_to_database
    StorageTests::EMLoop.new do
      alice = Vines::User.new(:jid => ALICE)
      storage = MockLdapStorage.new
      storage.ldap.expect(:authenticate, alice, [ALICE, 'secr3t'])
      user = storage.authenticate(ALICE, 'secr3t')
      refute_nil user
      assert_equal ALICE, user.jid.to_s
      assert_equal 0, storage.authenticate_calls
      assert_equal 1, storage.find_user_calls
      assert_equal 1, storage.save_user_calls
      assert storage.ldap.verify
    end
  end
end
