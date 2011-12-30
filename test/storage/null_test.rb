# encoding: UTF-8

require 'vines'
require 'minitest/autorun'

class NullStorageTest < MiniTest::Unit::TestCase
  def setup
    @storage = Vines::Storage::Null.new
    @user = Vines::User.new(jid: 'alice@wonderland.lit')
  end

  def test_find_user_returns_nil
    assert_nil @storage.find_user(@user.jid)
    @storage.save_user(@user)
    assert_nil @storage.find_user(@user.jid)
  end

  def test_find_vcard_returns_nil
    assert_nil @storage.find_vcard(@user.jid)
    @storage.save_vcard(@user.jid, 'card')
    assert_nil @storage.find_vcard(@user.jid)
  end

  def test_find_fragment_returns_nil
    assert_nil @storage.find_fragment(@user.jid, 'node')
    @storage.save_fragment(@user.jid, 'node')
    assert_nil @storage.find_fragment(@user.jid, 'node')
    nil
  end
end
