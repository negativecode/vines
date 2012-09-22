# encoding: UTF-8

require 'test_helper'

describe Vines::Config::PubSub do
  subject { config.pubsub('topics.wonderland.lit') }
  let(:alice) { Vines::JID.new('alice@wonderland.lit') }
  let(:romeo) { Vines::JID.new('romeo@verona.lit') }
  let(:config) do
    @config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
        pubsub 'topics'
      end
    end
  end

  it 'adds and deletes a topic node' do
    topic = 'rhode_island_is_neither_a_road_nor_an_island'
    refute subject.node?(topic)
    subject.add_node(topic)
    assert subject.node?(topic)
    subject.delete_node(topic)
    refute subject.node?(topic)
  end

  it 'ignores deleting a missing topic node' do
    topic = 'kittens_vs_puppies'
    refute subject.node?(topic)
    subject.delete_node(topic)
    refute subject.node?(topic)
  end

  it 'subscribes a jid to a node' do
    topic = 'with_jid'
    jid = Vines::JID.new('alice@wonderland.lit')
    subject.add_node(topic)
    subject.subscribe(topic, jid)
    assert subject.subscribed?(topic, jid.to_s)
    assert subject.subscribed?(topic, jid)
  end

  it 'does not allow remote jids to subscribe to a node by default' do
    topic = 'remote_jids_failed'
    jid = 'romeo@verona.lit'
    subject.add_node(topic)
    subject.subscribe(topic, jid)
    refute subject.subscribed?(topic, jid)
  end

  it 'allows remote jid subscriptions when cross domain messages are enabled' do
    topic = 'remote_jids_allowed'
    jid = 'romeo@verona.lit'
    config.vhost('wonderland.lit').cross_domain_messages true
    subject.add_node(topic)
    subject.subscribe(topic, jid)
    assert subject.subscribed?(topic, jid)
  end

  it 'ignores subscribing to a missing node' do
    topic = 'bogus'
    jid = 'alice@wonderland.lit'
    refute subject.node?(topic)
    subject.subscribe(topic, jid)
    refute subject.node?(topic)
    refute subject.subscribed?(topic, jid)
  end

  it 'deletes the node after unsubscribing' do
    topic = 'delete_me'
    jid = 'alice@wonderland.lit/tea'
    subject.add_node(topic)
    subject.subscribe(topic, jid)
    assert subject.subscribed?(topic, jid)
    subject.unsubscribe(topic, jid)
    refute subject.subscribed?(topic, jid)
    refute subject.node?(topic)
  end

  it 'unsubscribes a jid from all topics' do
    topic = 'pirates_vs_ninjas'
    topic2 = 'pirates_vs_ninjas_2'
    jid = 'alice@wonderland.lit'
    jid2 = 'hatter@wonderland.lit'
    subject.add_node(topic)
    subject.add_node(topic2)

    subject.subscribe(topic, jid)
    subject.subscribe(topic, jid2)
    subject.subscribe(topic2, jid)
    assert subject.subscribed?(topic, jid)
    assert subject.subscribed?(topic, jid2)
    assert subject.subscribed?(topic2, jid)

    subject.unsubscribe_all(jid)
    refute subject.node?(topic2)
    refute subject.subscribed?(topic, jid)
    refute subject.subscribed?(topic2, jid)
    assert subject.subscribed?(topic, jid2)
  end

  describe 'when publishing a message to a topic node' do
    let(:xml) do
      node(%q{
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
        </iq>})
    end

    let(:recipient) do
      recipient = MiniTest::Mock.new
      recipient.expect :user, Vines::User.new(jid: alice)
      class << recipient
        attr_accessor :nodes
        def write(node)
          @nodes ||= []
          @nodes << node
        end
      end
      recipient
    end

    before do
      router = MiniTest::Mock.new
      router.expect :connected_resources, [recipient], [alice, 'topics.wonderland.lit']
      class << router
        attr_accessor :nodes
        def route(node)
          @nodes ||= []
          @nodes << node
        end
      end

      class << config
        attr_accessor :router
      end
      config.router = router
      config.vhost('wonderland.lit').cross_domain_messages true

      subject.add_node(topic)
      subject.subscribe(topic, alice)
      subject.subscribe(topic, romeo)
    end

    let(:topic) { 'pirates_vs_ninjas' }

    it 'writes the message to local connected resource streams' do
      expected = xml.clone
      expected['to'] = 'alice@wonderland.lit'
      expected['from'] = 'topics.wonderland.lit'

      subject.publish(topic, xml)
      config.router.verify
      recipient.verify

      # id is random
      received = recipient.nodes.first
      received['id'].wont_be_nil
      received.remove_attribute('id')
      received.must_equal expected
    end

    it 'routes the message to remote jids' do
      expected = xml.clone
      expected['to'] = 'romeo@verona.lit'
      expected['from'] = 'topics.wonderland.lit'

      subject.publish(topic, xml)
      config.router.verify

      # id is random
      routed = config.router.nodes.first
      routed['id'].wont_be_nil
      routed.remove_attribute('id')
      routed.must_equal expected
    end
  end
end
