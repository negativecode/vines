# encoding: UTF-8

require 'vines'
require 'ext/nokogiri'
require 'minitest/mock'
require 'test/unit'

class SubscribeTest < Test::Unit::TestCase
  def test_outbound_subscribe_to_local_jid_but_missing_contact
    alice = Vines::JID.new('alice@wonderland.lit/tea')
    hatter = Vines::JID.new('hatter@wonderland.lit')

    contact = Vines::Contact.new(:jid => hatter)

    user = MiniTest::Mock.new
    user.expect(:jid, alice)
    user.expect(:request_subscription, nil, [hatter.to_s])
    user.expect(:contact, contact, [hatter])

    storage = MiniTest::Mock.new
    storage.expect(:save_user, nil, [user])
    storage.expect(:find_user, nil, [hatter])

    recipient = MiniTest::Mock.new
    recipient.expect(:user, Vines::User.new(:jid => hatter))
    def recipient.nodes; @nodes; end
    def recipient.write(node)
      @nodes ||= []
      @nodes << node
    end

    router = MiniTest::Mock.new
    router.expect(:interested_resources, [recipient], [alice])

    stream = MiniTest::Mock.new
    stream.expect(:domain, 'wonderland.lit')
    stream.expect(:storage, storage, ['wonderland.lit'])
    stream.expect(:user, user)
    stream.expect(:router, router)
    stream.expect(:update_user_streams, nil, [user])
    def stream.nodes; @nodes; end
    def stream.write(node)
      @nodes ||= []
      @nodes << node
    end

    node = node(%q{<presence id="42" to="hatter@wonderland.lit" type="subscribe"/>})
    stanza = Vines::Stanza::Presence::Subscribe.new(node, stream)
    def stanza.route_iq; false; end
    def stanza.inbound?; false; end
    def stanza.local?;   true; end

    stanza.process
    assert stream.verify
    assert user.verify
    assert storage.verify
    assert router.verify
    assert_equal 1, stream.nodes.size
    assert_equal 1, recipient.nodes.size

    expected = node(%q{<presence from="hatter@wonderland.lit" id="42" to="alice@wonderland.lit" type="unsubscribed"/>})
    assert_equal expected, stream.nodes[0]

    query = %q{<query xmlns="jabber:iq:roster"><item jid="hatter@wonderland.lit" subscription="none"/></query>}
    expected = node(%Q{<iq to="alice@wonderland.lit/tea" type="set">#{query}</iq>})
    recipient.nodes[0].remove_attribute('id') # id is random
    assert_equal expected, recipient.nodes[0]
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
