# encoding: UTF-8

require 'vines'
require 'ext/nokogiri'
require 'minitest/autorun'

class MessageTest < MiniTest::Unit::TestCase
  def setup
    @stream = MiniTest::Mock.new
  end

  def test_bad_type_returns_error
    node = node('<message type="bogus">hello!</message>')
    stanza = Vines::Stanza::Message.new(node, @stream)
    assert_raises(Vines::StanzaErrors::BadRequest) { stanza.process }
  end

  def test_missing_to_address_is_sent_to_sender
    alice = Vines::User.new(:jid => 'alice@wonderland.lit/tea')
    node = node('<message>hello!</message>')

    recipient = MiniTest::Mock.new
    recipient.expect(:user, alice)
    recipient.expect(:write, nil, [node])

    router = MiniTest::Mock.new
    router.expect(:local?, true, [node])
    router.expect(:connected_resources, [recipient], [alice.jid.bare])

    @stream.expect(:router, router)
    @stream.expect(:user, alice)

    stanza = Vines::Stanza::Message.new(node, @stream)
    stanza.process
    assert @stream.verify
    assert router.verify
    assert recipient.verify
  end

  def test_message_to_non_user_is_ignored
    bogus = Vines::JID.new('bogus@wonderland.lit/cake')
    node = node(%Q{<message to="#{bogus}">hello!</message>})

    router = MiniTest::Mock.new
    router.expect(:local?, true, [node])
    router.expect(:connected_resources, [], [bogus])

    storage = MiniTest::Mock.new
    storage.expect(:find_user, nil, [bogus])

    @stream.expect(:router, router)
    @stream.expect(:storage, storage, [bogus.domain])

    stanza = Vines::Stanza::Message.new(node, @stream)
    stanza.process
    assert @stream.verify
    assert router.verify
    assert storage.verify
  end

  def test_message_to_offline_user_returns_error
    hatter = Vines::User.new(:jid => 'hatter@wonderland.lit/cake')
    node = node(%Q{<message to="#{hatter.jid}">hello!</message>})

    router = MiniTest::Mock.new
    router.expect(:local?, true, [node])
    router.expect(:connected_resources, [], [hatter.jid])

    storage = MiniTest::Mock.new
    storage.expect(:find_user, hatter, [hatter.jid])

    @stream.expect(:router, router)
    @stream.expect(:storage, storage, [hatter.jid.domain])

    stanza = Vines::Stanza::Message.new(node, @stream)
    assert_raises(Vines::StanzaErrors::ServiceUnavailable) { stanza.process }
    assert @stream.verify
    assert router.verify
    assert storage.verify
  end

  def test_message_to_local_user_in_different_domain_is_delivered
    alice = Vines::User.new(:jid => 'alice@wonderland.lit/tea')
    romeo = Vines::User.new(:jid => 'romeo@verona.lit/balcony')
    node = node(%Q{<message to="#{romeo.jid}">hello!</message>})
    expected = node(%Q{<message to="#{romeo.jid}" from="#{alice.jid}">hello!</message>})

    recipient = MiniTest::Mock.new
    recipient.expect(:user, romeo)
    recipient.expect(:write, nil, [expected])

    router = MiniTest::Mock.new
    router.expect(:local?, true, [node])
    router.expect(:connected_resources, [recipient], [romeo.jid])

    @stream.expect(:router, router)
    @stream.expect(:user, alice)

    stanza = Vines::Stanza::Message.new(node, @stream)
    stanza.process
    assert @stream.verify
    assert router.verify
    assert recipient.verify
  end

  def test_message_to_remote_user_is_routed
    alice = Vines::User.new(:jid => 'alice@wonderland.lit/tea')
    romeo = Vines::User.new(:jid => 'romeo@verona.lit/balcony')
    node = node(%Q{<message to="#{romeo.jid}">hello!</message>})
    expected = node(%Q{<message to="#{romeo.jid}" from="#{alice.jid}">hello!</message>})

    router = MiniTest::Mock.new
    router.expect(:local?, false, [node])
    router.expect(:route, nil, [expected])

    @stream.expect(:router, router)
    @stream.expect(:user, alice)

    stanza = Vines::Stanza::Message.new(node, @stream)
    stanza.process
    assert @stream.verify
    assert router.verify
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
