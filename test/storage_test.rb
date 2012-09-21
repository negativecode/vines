# encoding: UTF-8

require 'storage_tests'
require 'test_helper'

describe Vines::Storage do
  ALICE = 'alice@wonderland.lit'.freeze

  class MockLdapStorage < Vines::Storage
    attr_reader :authenticate_calls, :find_user_calls, :save_user_calls

    def initialize(found_user=nil)
      @found_user = found_user
      @authenticate_calls = @find_user_calls = @save_user_calls = 0
      @ldap = Class.new do
        attr_accessor :user, :auth
        def authenticate(username, password)
          @auth ||= []
          @auth << [username, password]
          @user
        end
      end.new
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

  describe '#authenticate_with_ldap' do
    it 'fails when given a bad password' do
      StorageTests::EMLoop.new do
        storage = MockLdapStorage.new
        storage.ldap.user = nil
        user = storage.authenticate(ALICE, 'bogus')
        assert_nil user
        assert_equal 0, storage.authenticate_calls
        assert_equal 0, storage.find_user_calls
        assert_equal 0, storage.save_user_calls
        assert_equal [ALICE, 'bogus'], storage.ldap.auth.first
      end
    end

    it 'succeeds when user exists in database' do
      StorageTests::EMLoop.new do
        alice = Vines::User.new(:jid => ALICE)
        storage = MockLdapStorage.new(alice)
        storage.ldap.user = alice
        user = storage.authenticate(ALICE, 'secr3t')
        refute_nil user
        assert_equal ALICE, user.jid.to_s
        assert_equal 0, storage.authenticate_calls
        assert_equal 1, storage.find_user_calls
        assert_equal 0, storage.save_user_calls
        assert_equal [ALICE, 'secr3t'], storage.ldap.auth.first
      end
    end

    it 'succeeds and saves user to the database' do
      StorageTests::EMLoop.new do
        alice = Vines::User.new(:jid => ALICE)
        storage = MockLdapStorage.new
        storage.ldap.user = alice
        user = storage.authenticate(ALICE, 'secr3t')
        refute_nil user
        assert_equal ALICE, user.jid.to_s
        assert_equal 0, storage.authenticate_calls
        assert_equal 1, storage.find_user_calls
        assert_equal 1, storage.save_user_calls
        assert_equal [ALICE, 'secr3t'], storage.ldap.auth.first
      end
    end
  end
end
