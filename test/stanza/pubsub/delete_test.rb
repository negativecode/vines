# encoding: UTF-8

require 'test_helper'

describe Vines::Stanza::PubSub::Delete do
  subject      { Vines::Stanza::PubSub::Delete.new(xml, stream) }
  let(:alice)  { Vines::User.new(jid: 'alice@wonderland.lit/tea') }
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
      attr_accessor :config, :domain, :nodes, :user
      def write(node)
        @nodes ||= []
        @nodes << node
      end
    end
    stream.config = config
    stream.domain = 'wonderland.lit'
    stream.user = alice
  end

  describe 'when missing a to address' do
    let(:xml) do
      node(%q{
        <iq type='set' id='42'>
          <pubsub xmlns='http://jabber.org/protocol/pubsub'>
            <delete node='game_13'/>
          </pubsub>
        </iq>
      })
    end

    it 'raises a feature-not-implemented stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::FeatureNotImplemented
      stream.verify
    end
  end

  describe 'when addressed to a bare server domain jid' do
    let(:xml) do
      node(%q{
        <iq type='set' to='wonderland.lit' id='42'>
          <pubsub xmlns='http://jabber.org/protocol/pubsub'>
            <delete node='game_13'/>
          </pubsub>
        </iq>
      })
    end

    it 'raises a feature-not-implemented stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::FeatureNotImplemented
      stream.verify
    end
  end

  describe 'when addressed to a non-pubsub address' do
    let(:router) { MiniTest::Mock.new }
    let(:xml) do
      node(%q{
        <iq type='set' to='bogus.wonderland.lit' id='42'>
          <pubsub xmlns='http://jabber.org/protocol/pubsub'>
            <delete node='game_13'/>
          </pubsub>
        </iq>
      })
    end

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

  describe 'when stanza contains multiple delete elements' do
    let(:xml) do
      node(%q{
        <iq type='set' to='games.wonderland.lit' id='42'>
          <pubsub xmlns='http://jabber.org/protocol/pubsub'>
            <delete node='game_13'/>
            <delete node='game_14'/>
          </pubsub>
        </iq>
      })
    end

    it 'raises a bad-request stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::BadRequest
      stream.verify
    end
  end

  describe 'when deleting a missing node' do
    let(:xml) do
      node(%q{
        <iq type='set' to='games.wonderland.lit' id='42'>
          <pubsub xmlns='http://jabber.org/protocol/pubsub'>
            <delete node='game_13'/>
          </pubsub>
        </iq>
      })
    end

    it 'raises an item-not-found stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::ItemNotFound
      stream.verify
    end
  end

  describe 'when valid stanza is received' do
    let(:pubsub) { MiniTest::Mock.new }
    let(:xml) do
      node(%q{
        <iq type='set' to='games.wonderland.lit' id='42'>
          <pubsub xmlns='http://jabber.org/protocol/pubsub'>
            <delete node='game_13'/>
          </pubsub>
        </iq>
      })
    end

    let(:result) { node(%Q{<iq from="games.wonderland.lit" id="42" to="#{alice.jid}" type="result"/>}) }

    let(:broadcast) do
      node(%q{
        <message>
          <event xmlns="http://jabber.org/protocol/pubsub#event">
            <delete node="game_13"/>
          </event>
        </message>})
    end

    before do
      pubsub.expect :node?, true, ['game_13']
      pubsub.expect :publish, nil, ['game_13', broadcast]
      pubsub.expect :delete_node, nil, ['game_13']
    end

    it 'broadcasts the delete to subscribers' do
      subject.stub :pubsub, pubsub do
        subject.process
      end
      stream.verify
      pubsub.verify
    end

    it 'sends a result stanza to sender' do
      subject.stub :pubsub, pubsub do
        subject.process
      end
      stream.nodes.size.must_equal 1
      stream.nodes.first.must_equal result
    end
  end
end
