# encoding: UTF-8

require 'test_helper'

describe Vines::Stream::Parser do
  STREAM_START = '<stream:stream to="wonderland.lit" xmlns="jabber:client" xmlns:stream="http://etherx.jabber.org/streams">'.freeze

  before do
    @events = []
    @parser = Vines::Stream::Parser.new.tap do |p|
      p.stream_open  {|el| @events << el }
      p.stream_close {     @events << :close }
      p.stanza       {|el| @events << el }
    end
  end

  def test_xpath_to_subclass
    expected = []
    stanzas = [
      ['<message></message>', Vines::Stanza::Message],
      ['<presence/>', Vines::Stanza::Presence],
      ['<presence type="bogus"/>', Vines::Stanza::Presence],
      ['<presence type="error"/>', Vines::Stanza::Presence::Error],
      ['<presence type="probe"/>', Vines::Stanza::Presence::Probe],
      ['<presence type="subscribe"/>', Vines::Stanza::Presence::Subscribe],
      ['<presence type="subscribed"/>', Vines::Stanza::Presence::Subscribed],
      ['<presence type="unavailable"/>', Vines::Stanza::Presence::Unavailable],
      ['<presence type="unsubscribe"/>', Vines::Stanza::Presence::Unsubscribe],
      ['<presence type="unsubscribed"/>', Vines::Stanza::Presence::Unsubscribed],
      ['<iq id="42" type="get"><query xmlns="http://jabber.org/protocol/disco#info"></query></iq>', Vines::Stanza::Iq::Query::DiscoInfo],
      ['<iq id="42" type="get"><query xmlns="http://jabber.org/protocol/disco#items"></query></iq>', Vines::Stanza::Iq::Query::DiscoItems],
      ['<iq id="42" type="error"></iq>', Vines::Stanza::Iq::Error],
      ['<iq id="42" type="get"><query xmlns="jabber:iq:private"/></iq>', Vines::Stanza::Iq::PrivateStorage],
      ['<iq id="42" type="set"><query xmlns="jabber:iq:private"/></iq>', Vines::Stanza::Iq::PrivateStorage],
      ['<iq id="42" type="get"><ping xmlns="urn:xmpp:ping"/></iq>', Vines::Stanza::Iq::Ping],
      ['<iq id="42" type="result"></iq>', Vines::Stanza::Iq::Result],
      ['<iq id="42" type="get"><query xmlns="jabber:iq:roster"/></iq>', Vines::Stanza::Iq::Query::Roster],
      ['<iq id="42" type="set"><query xmlns="jabber:iq:roster"/></iq>', Vines::Stanza::Iq::Query::Roster],
      ['<iq id="42" type="set"><session xmlns="urn:ietf:params:xml:ns:xmpp-session"/></iq>', Vines::Stanza::Iq::Session],
      ['<iq id="42" type="get"><vCard xmlns="vcard-temp"/></iq>', Vines::Stanza::Iq::Vcard],
      ['<iq type="get"><vCard xmlns="vcard-temp"/></iq>', Vines::Stanza::Iq],
      ['<iq id="42"><vCard xmlns="vcard-temp"/></iq>', Vines::Stanza::Iq],
      ['<iq><vCard xmlns="vcard-temp"/></iq>', Vines::Stanza::Iq],
      ['<bogus/>', NilClass],
    ]
    @parser << STREAM_START
    stanzas.each do |stanza, klass|
      @parser << stanza
      expected << klass
    end
    @parser << '</stream:stream>'
    assert_equal 'stream', @events.shift.name
    assert_equal :close, @events.pop
    assert_equal expected.size, @events.size
    @events.each_with_index do |ev, ix|
      assert_equal expected[ix], Vines::Stanza.from_node(ev, nil).class
    end
  end

  def test_stream_namespace_with_default_prefix
    @parser << STREAM_START
    assert_equal 1, @events.size
    stream = @events.shift
    assert_equal 'stream', stream.name
    refute_nil stream.namespace
    assert_equal 'stream', stream.namespace.prefix
    assert_equal 'http://etherx.jabber.org/streams', stream.namespace.href
    expected = {'xmlns' => 'jabber:client', 'xmlns:stream' => 'http://etherx.jabber.org/streams'}
    assert_equal expected, stream.namespaces
  end

  def test_stanzas_ignore_default_namespace
    @parser << STREAM_START
    @parser << '<message to="alice@wonderland.lit">hello!</message>'
    assert_equal 2, @events.size
    @events.shift # discard stream
    msg = @events.shift
    assert_equal 'message', msg.name
    assert msg.namespaces.empty?
    assert_nil msg.namespace
  end

  def test_nested_elements_have_namespace
    @parser << STREAM_START
    @parser << %q{
      <iq from='alice@wonderland.lit/tea' id='42' type='set'>
        <query xmlns='jabber:iq:roster'>
          <item jid='hatter@wonderland.lit' name='Mad Hatter'>
            <group>Tea Party</group>
          </item>
        </query>
      </iq>
    }
    assert_equal 2, @events.size
    @events.shift # discard stream
    iq = @events.shift
    assert_equal 'iq', iq.name
    assert iq.namespaces.empty?
    assert_nil iq.namespace

    query = iq.elements.first
    refute_nil query.namespace
    assert_nil query.namespace.prefix
    assert_equal 'jabber:iq:roster', query.namespace.href
    expected = {'xmlns' => 'jabber:iq:roster'}
    assert_equal expected, query.namespaces
  end

  def test_error_stanzas_have_stream_namespace
    @parser << STREAM_START
    @parser << '<stream:error><not-well-formed xmlns="urn:ietf:params:xml:ns:xmpp-streams"/></stream:error>'
    assert_equal 2, @events.size
    @events.shift # discard stream
    error = @events.shift
    assert_equal 'error', error.name
    refute_nil error.namespace
    assert_equal 'stream', error.namespace.prefix
    assert_equal 'http://etherx.jabber.org/streams', error.namespace.href
    expected = {'xmlns:stream' => 'http://etherx.jabber.org/streams'}
    assert_equal expected, error.namespaces
  end
end
