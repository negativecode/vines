# encoding: UTF-8

require 'test_helper'

describe Vines::Stanza::PubSub::Publish do
  subject      { Vines::Stanza::PubSub::Publish.new(xml, stream) }
  let(:user)   { Vines::User.new(jid: 'alice@wonderland.lit/tea') }
  let(:stream) { MiniTest::Mock.new }
  let(:config) do
    Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
        pubsub 'games'
      end
    end
  end

  before do
    class << stream
      attr_accessor :config, :nodes, :user
      def write(node)
        @nodes ||= []
        @nodes << node
      end
    end
    stream.config = config
    stream.user = user
  end

  describe 'when missing a to address' do
    let(:xml) { publish('') }

    it 'raises a feature-not-implemented stanza error' do
      stream.expect(:domain, 'wonderland.lit')
      -> { subject.process }.must_raise Vines::StanzaErrors::FeatureNotImplemented
      stream.verify
    end
  end

  describe 'when addressed to bare server domain' do
    let(:xml) { publish('wonderland.lit') }

    it 'raises a feature-not-implemented stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::FeatureNotImplemented
      stream.verify
    end
  end

  describe 'when addressed to a non-pubsub component' do
    let(:router) { MiniTest::Mock.new }
    let(:xml) { publish('bogus.wonderland.lit') }

    before do
      router.expect :route, nil, [xml]
      stream.expect :router, router
    end

    it 'routes rather than handle locally' do
      subject.process
      stream.verify
      router.verify
    end
  end

  describe 'when publishing to multiple nodes' do
    let(:xml) do
      node(%q{
        <iq type='set' to='games.wonderland.lit' id='42'>
          <pubsub xmlns='http://jabber.org/protocol/pubsub'>
            <publish node='game_13'>
              <item id='item_42'>
                <entry xmlns='http://www.w3.org/2005/Atom'>
                  <title>Test</title>
                  <summary>This is a summary.</summary>
                </entry>
              </item>
            </publish>
            <publish node='game_13'>
              <item id='item_42'>
                <entry xmlns='http://www.w3.org/2005/Atom'>
                  <title>Test</title>
                  <summary>This is a summary.</summary>
                </entry>
              </item>
            </publish>
          </pubsub>
        </iq>
      })
    end

    it 'raises a bad-request stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::BadRequest
      stream.verify
    end
  end

  describe 'when publishing multiple items' do
    let(:pubsub) { MiniTest::Mock.new }
    let(:xml) do
      node(%q{
        <iq type='set' to='games.wonderland.lit' id='42'>
          <pubsub xmlns='http://jabber.org/protocol/pubsub'>
            <publish node='game_13'>
              <item id='item_42'>
                <entry xmlns='http://www.w3.org/2005/Atom'>
                  <title>Test</title>
                  <summary>This is a summary.</summary>
                </entry>
              </item>
              <item id="item_43">bad</item>
            </publish>
          </pubsub>
        </iq>
      })
    end

    it 'raises a bad-request stanza error' do
      pubsub.expect :node?, true, ['game_13']
      subject.stub :pubsub, pubsub do
        -> { subject.process }.must_raise Vines::StanzaErrors::BadRequest
      end
      stream.verify
      pubsub.verify
    end
  end

  describe 'when publishing one item with multiple payloads' do
    let(:pubsub) { MiniTest::Mock.new }
    let(:xml) do
      node(%q{
        <iq type='set' to='games.wonderland.lit' id='42'>
          <pubsub xmlns='http://jabber.org/protocol/pubsub'>
            <publish node='game_13'>
              <item id='item_42'>
                <entry xmlns='http://www.w3.org/2005/Atom'>
                  <title>Test</title>
                  <summary>This is a summary.</summary>
                </entry>
                <entry>bad</entry>
              </item>
            </publish>
          </pubsub>
        </iq>
      })
    end

    it 'raises a bad-request stanza error' do
      pubsub.expect :node?, true, ['game_13']
      subject.stub :pubsub, pubsub do
        -> { subject.process }.must_raise Vines::StanzaErrors::BadRequest
      end
      stream.verify
      pubsub.verify
    end
  end

  describe 'when publishing with no payload' do
    let(:pubsub) { MiniTest::Mock.new }
    let(:xml) do
      node(%q{
        <iq type='set' to='games.wonderland.lit' id='42'>
          <pubsub xmlns='http://jabber.org/protocol/pubsub'>
            <publish node='game_13'>
              <item id='item_42'>
              </item>
            </publish>
          </pubsub>
        </iq>
      })
    end

    it 'raises a bad-request stanza error' do
      pubsub.expect :node?, true, ['game_13']
      subject.stub :pubsub, pubsub do
        -> { subject.process }.must_raise Vines::StanzaErrors::BadRequest
      end
      stream.verify
      pubsub.verify
    end
  end

  describe 'when publishing to a missing node' do
    let(:xml) { publish('games.wonderland.lit') }

    it 'raises an item-not-found stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::ItemNotFound
      stream.verify
    end
  end

  describe 'when publishing an item without an id' do
    let(:pubsub) { MiniTest::Mock.new }
    let(:xml) { publish('games.wonderland.lit', '') }
    let(:broadcast) { message_broadcast('') }
    let(:response) do
      node(%q{
        <iq from="games.wonderland.lit" id="42" to="alice@wonderland.lit/tea" type="result">
          <pubsub xmlns="http://jabber.org/protocol/pubsub">
            <publish node="game_13">
              <item/>
            </publish>
          </pubsub>
        </iq>})
    end

    before do
      pubsub.expect :node?, true, ['game_13']
      def pubsub.published; @published; end
      def pubsub.publish(node, message)
        @published ||= []
        @published << [node, message]
      end
    end

    it 'generates an item id in the response' do
      subject.stub :pubsub, pubsub do
        subject.process
      end
      stream.verify
      pubsub.verify
      stream.nodes.size.must_equal 1

      # id is random
      item = stream.nodes.first.xpath('ns:pubsub/ns:publish/ns:item',
        'ns' => 'http://jabber.org/protocol/pubsub').first
      item['id'].wont_be_nil
      item.remove_attribute('id')
      stream.nodes.first.must_equal response
    end

    it 'broadcasts the message with the generated item id' do
      subject.stub :pubsub, pubsub do
        subject.process
      end
      stream.verify
      pubsub.verify
      stream.nodes.size.must_equal 1

      published_node, published_message = *pubsub.published[0]
      published_node.must_equal 'game_13'
      # id is random
      item = published_message.xpath('ns:event/ns:items/ns:item',
        'ns' => 'http://jabber.org/protocol/pubsub#event').first
      item['id'].wont_be_nil
      item.remove_attribute('id')
      published_message.must_equal broadcast
    end
  end

  describe 'when publishing a valid stanza' do
    let(:pubsub) { MiniTest::Mock.new }
    let(:xml) { publish('games.wonderland.lit') }
    let(:response) { result(user.jid, 'games.wonderland.lit') }
    let(:broadcast) { message_broadcast('item_42') }

    it 'broadcasts and returns result to sender' do
      pubsub.expect :node?, true, ['game_13']
      pubsub.expect :publish, nil, ['game_13', broadcast]

      subject.stub :pubsub, pubsub do
        subject.process
      end

      stream.nodes.size.must_equal 1
      stream.nodes.first.must_equal response
      stream.verify
      pubsub.verify
    end
  end

  private

  def message_broadcast(item_id)
    item_id = (item_id.nil? || item_id.empty?) ?  ' ' : " id='#{item_id}' "
    node(%Q{
      <message>
        <event xmlns="http://jabber.org/protocol/pubsub#event">
          <items node="game_13">
            <item#{item_id}publisher="alice@wonderland.lit/tea">
              <entry xmlns="http://www.w3.org/2005/Atom">
                <title>Test</title>
                <summary>This is a summary.</summary>
              </entry>
            </item>
          </items>
        </event>
      </message>})
  end

  def publish(to, item_id='item_42')
    item_id = "id='#{item_id}'" unless item_id.nil? || item_id.empty?
    body = %Q{
      <pubsub xmlns='http://jabber.org/protocol/pubsub'>
        <publish node='game_13'>
          <item #{item_id}>
            <entry xmlns='http://www.w3.org/2005/Atom'>
              <title>Test</title>
              <summary>This is a summary.</summary>
            </entry>
          </item>
        </publish>
      </pubsub>}
    iq(type: 'set', to: to, id: 42, body: body)
  end

  def result(to, from)
    iq(from: from, id: 42, to: to, type: 'result')
  end
end
