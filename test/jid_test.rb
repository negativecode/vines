# encoding: UTF-8

require 'vines'
require 'minitest/autorun'

class JidTest < MiniTest::Unit::TestCase
  def test_nil_and_empty_jids
    [nil, ''].each do |text|
      Vines::JID.new(text) # shouldn't raise an error
      jid = Vines::JID.new(text)
      assert_nil jid.node
      assert_nil jid.resource
      assert_equal '', jid.domain
      assert_equal '', jid.to_s
      assert_equal '', jid.bare.to_s
    end
  end

  def test_jid_too_long_error
    Vines::JID.new('n' * 1023) # shouldn't raise an error
    assert_raises(ArgumentError) { Vines::JID.new('n' * 1024) }
    assert_raises(ArgumentError) { Vines::JID.new('n', 'd' * 1024) }
    assert_raises(ArgumentError) { Vines::JID.new('n', 'd', 'r' * 1024) }
    Vines::JID.new('n' * 1023, 'd' * 1023, 'r' * 1023) # shouldn't raise an error
  end

  def test_domain_only
    jid = Vines::JID.new('wonderland.lit')
    assert_equal 'wonderland.lit', jid.to_s
    assert_equal 'wonderland.lit', jid.domain
    assert_nil jid.node
    assert_nil jid.resource
    assert_equal jid, jid.bare
  end

  def test_bare_jid
    jid = Vines::JID.new('alice', 'wonderland.lit')
    assert_equal 'alice@wonderland.lit', jid.to_s
    assert_equal 'wonderland.lit', jid.domain
    assert_equal 'alice', jid.node
    assert_nil jid.resource
    assert_equal jid, jid.bare
  end

  def test_parsed_bare_jid
    jid = Vines::JID.new('alice@wonderland.lit')
    assert_equal 'alice@wonderland.lit', jid.to_s
    assert_equal 'wonderland.lit', jid.domain
    assert_equal 'alice', jid.node
    assert_nil jid.resource
    assert_equal jid, jid.bare
  end

  def test_full_jid
    jid = Vines::JID.new('alice', 'wonderland.lit', 'tea')
    assert_equal 'alice@wonderland.lit/tea', jid.to_s
    assert_equal 'wonderland.lit', jid.domain
    assert_equal 'alice', jid.node
    assert_equal 'tea', jid.resource
    refute_equal jid, jid.bare
  end

  def test_parsed_full_jid
    jid = Vines::JID.new('alice@wonderland.lit/tea')
    assert_equal 'alice@wonderland.lit/tea', jid.to_s
    assert_equal 'wonderland.lit', jid.domain
    assert_equal 'alice', jid.node
    assert_equal 'tea', jid.resource
    refute_equal jid, jid.bare
  end
end
