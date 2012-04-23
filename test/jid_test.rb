# encoding: UTF-8

require 'vines'
require 'minitest/autorun'

describe Vines::JID do
  it 'handles empty input' do
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

  it 'raises when a jid part is too long' do
    Vines::JID.new('n' * 1023) # shouldn't raise an error
    assert_raises(ArgumentError) { Vines::JID.new('n' * 1024) }
    assert_raises(ArgumentError) { Vines::JID.new('n', 'd' * 1024) }
    assert_raises(ArgumentError) { Vines::JID.new('n', 'd', 'r' * 1024) }
    Vines::JID.new('n' * 1023, 'd' * 1023, 'r' * 1023) # shouldn't raise an error
  end

  it 'correctly handles domain only jids' do
    jid = Vines::JID.new('wonderland.lit')
    assert_equal 'wonderland.lit', jid.to_s
    assert_equal 'wonderland.lit', jid.domain
    assert_nil jid.node
    assert_nil jid.resource
    assert_equal jid, jid.bare
    assert jid.domain?
    refute jid.empty?
  end

  it 'correctly handles bare jid components' do
    jid = Vines::JID.new('alice', 'wonderland.lit')
    assert_equal 'alice@wonderland.lit', jid.to_s
    assert_equal 'wonderland.lit', jid.domain
    assert_equal 'alice', jid.node
    assert_nil jid.resource
    assert_equal jid, jid.bare
    refute jid.domain?
    refute jid.empty?
  end

  it 'correctly parses bare jids' do
    jid = Vines::JID.new('alice@wonderland.lit')
    assert_equal 'alice@wonderland.lit', jid.to_s
    assert_equal 'wonderland.lit', jid.domain
    assert_equal 'alice', jid.node
    assert_nil jid.resource
    assert_equal jid, jid.bare
    refute jid.domain?
    refute jid.empty?
  end

  it 'correctly handles full jid components' do
    jid = Vines::JID.new('alice', 'wonderland.lit', 'tea')
    assert_equal 'alice@wonderland.lit/tea', jid.to_s
    assert_equal 'wonderland.lit', jid.domain
    assert_equal 'alice', jid.node
    assert_equal 'tea', jid.resource
    refute_equal jid, jid.bare
    refute jid.domain?
    refute jid.empty?
  end

  it 'correctly parses full jids' do
    jid = Vines::JID.new('alice@wonderland.lit/tea')
    assert_equal 'alice@wonderland.lit/tea', jid.to_s
    assert_equal 'wonderland.lit', jid.domain
    assert_equal 'alice', jid.node
    assert_equal 'tea', jid.resource
    refute_equal jid, jid.bare
    refute jid.domain?
    refute jid.empty?
  end

  it 'accepts separator characters in resource part' do
    jid = Vines::JID.new('alice@wonderland.lit/foo/bar@blarg test')
    assert_equal 'alice', jid.node
    assert_equal 'wonderland.lit', jid.domain
    assert_equal 'foo/bar@blarg test', jid.resource
  end

  it 'accepts separator characters in resource part with missing node part' do
    jid = Vines::JID.new('wonderland.lit/foo/bar@blarg')
    assert_nil jid.node
    assert_equal 'wonderland.lit', jid.domain
    assert_equal 'foo/bar@blarg', jid.resource
    refute jid.domain?
  end

  it 'accepts strange characters in node part' do
    jid = Vines::JID.new(%q{nasty!#$%()*+,-.;=?[\]^_`{|}~node@example.com})
    jid.node.must_equal %q{nasty!#$%()*+,-.;=?[\]^_`{|}~node}
    jid.domain.must_equal 'example.com'
    jid.resource.must_be_nil
  end

  it 'accepts strange characters in resource part' do
    jid = Vines::JID.new(%q{node@example.com/repulsive !#"$%&'()*+,-./:;<=>?@[\]^_`{|}~resource})
    jid.node.must_equal 'node'
    jid.domain.must_equal 'example.com'
    jid.resource.must_equal %q{repulsive !#"$%&'()*+,-./:;<=>?@[\]^_`{|}~resource}
  end

  it 'rejects empty jid parts' do
    assert_raises(ArgumentError) { Vines::JID.new('@wonderland.lit') }
    assert_raises(ArgumentError) { Vines::JID.new('wonderland.lit/') }
    assert_raises(ArgumentError) { Vines::JID.new('@') }
    assert_raises(ArgumentError) { Vines::JID.new('alice@') }
    assert_raises(ArgumentError) { Vines::JID.new('/') }
    assert_raises(ArgumentError) { Vines::JID.new('/res') }
    assert_raises(ArgumentError) { Vines::JID.new('@/') }
  end

  it 'rejects invalid characters' do
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
    assert_raises(ArgumentError) { Vines::JID.new("alice@w\u0000onderland.lit") }
    assert_raises(ArgumentError) { Vines::JID.new("alice@wonderland.lit/\u0000res") }
  end
end
