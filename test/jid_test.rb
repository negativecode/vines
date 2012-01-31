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
      assert jid.empty?
      refute jid.domain?
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
    assert jid.domain?
    refute jid.empty?
  end

  def test_bare_jid
    jid = Vines::JID.new('alice', 'wonderland.lit')
    assert_equal 'alice@wonderland.lit', jid.to_s
    assert_equal 'wonderland.lit', jid.domain
    assert_equal 'alice', jid.node
    assert_nil jid.resource
    assert_equal jid, jid.bare
    refute jid.domain?
    refute jid.empty?
  end

  def test_parsed_bare_jid
    jid = Vines::JID.new('alice@wonderland.lit')
    assert_equal 'alice@wonderland.lit', jid.to_s
    assert_equal 'wonderland.lit', jid.domain
    assert_equal 'alice', jid.node
    assert_nil jid.resource
    assert_equal jid, jid.bare
    refute jid.domain?
    refute jid.empty?
  end

  def test_full_jid
    jid = Vines::JID.new('alice', 'wonderland.lit', 'tea')
    assert_equal 'alice@wonderland.lit/tea', jid.to_s
    assert_equal 'wonderland.lit', jid.domain
    assert_equal 'alice', jid.node
    assert_equal 'tea', jid.resource
    refute_equal jid, jid.bare
    refute jid.domain?
    refute jid.empty?
  end

  def test_parsed_full_jid
    jid = Vines::JID.new('alice@wonderland.lit/tea')
    assert_equal 'alice@wonderland.lit/tea', jid.to_s
    assert_equal 'wonderland.lit', jid.domain
    assert_equal 'alice', jid.node
    assert_equal 'tea', jid.resource
    refute_equal jid, jid.bare
    refute jid.domain?
    refute jid.empty?
  end

  def test_node_with_separators_in_resource
    jid = Vines::JID.new('alice@wonderland.lit/foo/bar@blarg')
    assert_equal 'alice', jid.node
    assert_equal 'wonderland.lit', jid.domain
    assert_equal 'foo/bar@blarg', jid.resource
  end

  def test_missing_node_with_separators_in_resource
    jid = Vines::JID.new('wonderland.lit/foo/bar@blarg')
    assert_nil jid.node
    assert_equal 'wonderland.lit', jid.domain
    assert_equal 'foo/bar@blarg', jid.resource
    refute jid.domain?
  end

  def test_empty_part_raises
    assert_raises(ArgumentError) { Vines::JID.new('@wonderland.lit') }
    assert_raises(ArgumentError) { Vines::JID.new('wonderland.lit/') }
    assert_raises(ArgumentError) { Vines::JID.new('@') }
    assert_raises(ArgumentError) { Vines::JID.new('alice@') }
    assert_raises(ArgumentError) { Vines::JID.new('/') }
    assert_raises(ArgumentError) { Vines::JID.new('/res') }
    assert_raises(ArgumentError) { Vines::JID.new('@/') }
  end

  def test_invalid_characters
    assert_raises(ArgumentError) { Vines::JID.new(%q{alice"s@wonderland.lit}) }
    assert_raises(ArgumentError) { Vines::JID.new(%q{alice&s@wonderland.lit}) }
    assert_raises(ArgumentError) { Vines::JID.new(%q{alice's@wonderland.lit}) }
    assert_raises(ArgumentError) { Vines::JID.new(%q{alice:s@wonderland.lit}) }
    assert_raises(ArgumentError) { Vines::JID.new(%q{alice<s@wonderland.lit}) }
    assert_raises(ArgumentError) { Vines::JID.new(%q{alice>s@wonderland.lit}) }
    assert_raises(ArgumentError) { Vines::JID.new("alice\u0000s@wonderland.lit") }
    assert_raises(ArgumentError) { Vines::JID.new("alice\ts@wonderland.lit") }
    assert_raises(ArgumentError) { Vines::JID.new("alice\rs@wonderland.lit") }
    assert_raises(ArgumentError) { Vines::JID.new("alice\ns@wonderland.lit") }
    assert_raises(ArgumentError) { Vines::JID.new("alice\vs@wonderland.lit") }
    assert_raises(ArgumentError) { Vines::JID.new("alice\fs@wonderland.lit") }
    assert_raises(ArgumentError) { Vines::JID.new(" alice@wonderland.lit") }
    assert_raises(ArgumentError) { Vines::JID.new("alice@wonderland.lit ") }
    assert_raises(ArgumentError) { Vines::JID.new("alice s@wonderland.lit") }
    assert_raises(ArgumentError) { Vines::JID.new("alice@w onderland.lit") }
    assert_raises(ArgumentError) { Vines::JID.new("alice@w\tonderland.lit") }
    assert_raises(ArgumentError) { Vines::JID.new("alice@w\ronderland.lit") }
    assert_raises(ArgumentError) { Vines::JID.new("alice@w\nonderland.lit") }
    assert_raises(ArgumentError) { Vines::JID.new("alice@w\vonderland.lit") }
    assert_raises(ArgumentError) { Vines::JID.new("alice@w\fonderland.lit") }
    assert_raises(ArgumentError) { Vines::JID.new("alice@wonderland.lit/ res") }
    assert_raises(ArgumentError) { Vines::JID.new("alice@w\u0000onderland.lit") }
    assert_raises(ArgumentError) { Vines::JID.new("alice@wonderland.lit/\u0000res") }
  end
end
