# encoding: UTF-8

require 'tmpdir'
require 'vines'
require 'ext/nokogiri'
require 'minitest/autorun'

class ConfigPubSubTest < MiniTest::Unit::TestCase
  def setup
    @config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
        pubsub 'topics'
      end
    end
    @pubsub = @config.pubsub('topics.wonderland.lit')
  end

  def test_add_node
    topic = 'rhode_island_is_neither_a_road_nor_an_island'
    refute @pubsub.node?(topic)
    @pubsub.add_node(topic)
    assert @pubsub.node?(topic)
    @pubsub.delete_node(topic)
    refute @pubsub.node?(topic)
  end

  def test_delete_missing_node
    topic = 'kittens_vs_puppies'
    refute @pubsub.node?(topic)
    @pubsub.delete_node(topic)
    refute @pubsub.node?(topic)
  end

  def test_subscribe_with_jid
    topic = 'with_jid'
    jid = Vines::JID.new('alice@wonderland.lit')
    @pubsub.add_node(topic)
    @pubsub.subscribe(topic, jid)
    assert @pubsub.subscribed?(topic, jid.to_s)
    assert @pubsub.subscribed?(topic, jid)
  end

  def test_subscribe_remote_jid_not_allowed
    topic = 'remote_jids_failed'
    jid = 'romeo@verona.lit'
    @pubsub.add_node(topic)
    @pubsub.subscribe(topic, jid)
    refute @pubsub.subscribed?(topic, jid)
  end

  def test_subscribe_remote_jid_is_allowed
    topic = 'remote_jids_allowed'
    jid = 'romeo@verona.lit'
    @config.vhost('wonderland.lit').cross_domain_messages true
    @pubsub.add_node(topic)
    @pubsub.subscribe(topic, jid)
    assert @pubsub.subscribed?(topic, jid)
  end

  def test_subscribe_missing_node
    topic = 'bogus'
    jid = 'alice@wonderland.lit'
    refute @pubsub.node?(topic)
    @pubsub.subscribe(topic, jid)
    refute @pubsub.node?(topic)
    refute @pubsub.subscribed?(topic, jid)
  end

  def test_unsubscribe_deletes_node
    topic = 'delete_me'
    jid = 'alice@wonderland.lit/tea'
    @pubsub.add_node(topic)
    @pubsub.subscribe(topic, jid)
    assert @pubsub.subscribed?(topic, jid)
    @pubsub.unsubscribe(topic, jid)
    refute @pubsub.subscribed?(topic, jid)
    refute @pubsub.node?(topic)
  end

  def test_unsubscribe_all
    topic = 'pirates_vs_ninjas'
    topic2 = 'pirates_vs_ninjas_2'
    jid = 'alice@wonderland.lit'
    jid2 = 'hatter@wonderland.lit'
    @pubsub.add_node(topic)
    @pubsub.add_node(topic2)

    @pubsub.subscribe(topic, jid)
    @pubsub.subscribe(topic, jid2)
    @pubsub.subscribe(topic2, jid)
    assert @pubsub.subscribed?(topic, jid)
    assert @pubsub.subscribed?(topic, jid2)
    assert @pubsub.subscribed?(topic2, jid)

    @pubsub.unsubscribe_all(jid)
    refute @pubsub.node?(topic2)
    refute @pubsub.subscribed?(topic, jid)
    refute @pubsub.subscribed?(topic2, jid)
    assert @pubsub.subscribed?(topic, jid2)
  end

  def test_publish
    topic = 'pirates_vs_ninjas'
    alice = Vines::JID.new('alice@wonderland.lit')
    romeo = Vines::JID.new('romeo@verona.lit')

    @config.vhost('wonderland.lit').cross_domain_messages true
    def @config.router
      unless @mock_router
        @mock_router = MiniTest::Mock.new
        def @mock_router.nodes; @nodes; end
        def @mock_router.route(node)
          @nodes ||= []
          @nodes << node
        end
      end
      @mock_router
    end

    recipient = recipient(alice)
    @config.router.expect(:connected_resources, [recipient], [alice, 'topics.wonderland.lit'])

    @pubsub.add_node(topic)
    @pubsub.subscribe(topic, alice)
    @pubsub.subscribe(topic, romeo)
    assert @pubsub.subscribed?(topic, alice)
    assert @pubsub.subscribed?(topic, romeo)

    node = node(%q{
      <iq type='set' to='topics.wonderland.lit'>
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <publish node='pirates_vs_ninjas'>
            <item id='item_42'>
              <entry xmlns='http://www.w3.org/2005/Atom'>
                <title>Test</title>
                <summary>This is a summary.</summary>
              </entry>
            </item>
          </publish>
        </pubsub>
      </iq>
    }.strip.gsub(/\n|\s{2,}/, ''))
    expected = node.clone

    @pubsub.publish(topic, node)

    assert @config.router.verify
    assert recipient.verify

    # id is random
    refute_nil recipient.nodes[0]['id']
    refute_nil @config.router.nodes[0]['id']
    recipient.nodes[0].remove_attribute('id')
    @config.router.nodes[0].remove_attribute('id')

    expected['to'] = 'alice@wonderland.lit'
    expected['from'] = 'topics.wonderland.lit'
    assert_equal expected, recipient.nodes[0]

    expected['to'] = 'romeo@verona.lit'
    assert_equal expected, @config.router.nodes[0]
  end

  private

  def recipient(jid)
    recipient = MiniTest::Mock.new
    recipient.expect(:user, Vines::User.new(jid: jid))
    def recipient.nodes; @nodes; end
    def recipient.write(node)
      @nodes ||= []
      @nodes << node
    end
    recipient
  end

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
