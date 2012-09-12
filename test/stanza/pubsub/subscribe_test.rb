# encoding: UTF-8

require 'test_helper'

describe Vines::Stanza::PubSub::Subscribe do
  subject      { Vines::Stanza::PubSub::Subscribe.new(xml, stream) }
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
    stream.user = alice
    stream.domain = 'wonderland.lit'
  end

  describe 'when missing a to address' do
    let(:xml) do
      node(%q{
        <iq type='set' id='42'>
          <pubsub xmlns='http://jabber.org/protocol/pubsub'>
            <subscribe node='game_13' jid="alice@wonderland.lit/tea"/>
          </pubsub>
        </iq>
      })
    end

    it 'raises a feature-not-implemented stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::FeatureNotImplemented
      stream.verify
    end
  end

  describe 'when addressed to a bare server domain' do
    let(:xml) do
      node(%q{
          <iq type='set' to='wonderland.lit' id='42'>
            <pubsub xmlns='http://jabber.org/protocol/pubsub'>
              <subscribe node='game_13' jid="alice@wonderland.lit/tea"/>
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
              <subscribe node='game_13' jid="alice@wonderland.lit/tea"/>
            </pubsub>
          </iq>
        })
    end

    it 'routes rather than handle locally' do
      router.expect :route, nil, [xml]
      stream.expect :router, router

      subject.process
      stream.verify
      router.verify
    end
  end

  describe 'when stanza contains multiple subscribe elements' do
    let(:xml) do
      node(%q{
          <iq type='set' to='games.wonderland.lit' id='42'>
            <pubsub xmlns='http://jabber.org/protocol/pubsub'>
              <subscribe node='game_13' jid="alice@wonderland.lit/tea"/>
              <subscribe node='game_14' jid="alice@wonderland.lit/tea"/>
            </pubsub>
          </iq>
        })
    end

    it 'raises a bad-request stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::BadRequest
      stream.verify
    end
  end

  describe 'when stanza is missing a subscribe element' do
    let(:xml) do
      node(%q{
          <iq type='set' to='games.wonderland.lit' id='42'>
            <pubsub xmlns='http://jabber.org/protocol/pubsub'>
              <subscribe node='game_13' jid="alice@wonderland.lit/tea"/>
            </pubsub>
          </iq>
        })
    end

    it 'raises an item-not-found stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::ItemNotFound
      stream.verify
    end
  end

  describe 'when attempting to subscribe to a node twice' do
    let(:pubsub) { MiniTest::Mock.new }
    let(:xml) do
      node(%q{
          <iq type='set' to='games.wonderland.lit' id='42'>
            <pubsub xmlns='http://jabber.org/protocol/pubsub'>
              <subscribe node='game_13' jid="alice@wonderland.lit/tea"/>
            </pubsub>
          </iq>
        })
    end

    before do
      pubsub.expect :node?, true, ['game_13']
      pubsub.expect :subscribed?, true, ['game_13', alice.jid]
    end

    it 'raises a policy-violation stanza error' do
      subject.stub :pubsub, pubsub do
        -> { subject.process }.must_raise Vines::StanzaErrors::PolicyViolation
      end
      stream.verify
      pubsub.verify
    end
  end

  describe 'when subscribing with an illegal jid' do
    let(:xml) do
      node(%q{
          <iq type='set' to='games.wonderland.lit' id='42'>
            <pubsub xmlns='http://jabber.org/protocol/pubsub'>
              <subscribe node='game_13' jid="not_alice@wonderland.lit/tea"/>
            </pubsub>
          </iq>
        })
    end

    it 'raises a bad-request stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::BadRequest
      stream.verify
    end
  end

  describe 'when subscribing with a valid stanza' do
    let(:xml) do
      node(%q{
          <iq type='set' to='games.wonderland.lit' id='42'>
            <pubsub xmlns='http://jabber.org/protocol/pubsub'>
              <subscribe node='game_13' jid="alice@wonderland.lit/tea"/>
            </pubsub>
          </iq>
        })
    end

    let(:expected) do
      node(%q{
        <iq from="games.wonderland.lit" id="42" to="alice@wonderland.lit/tea" type="result">
            <pubsub xmlns="http://jabber.org/protocol/pubsub">
              <subscription node="game_13" jid="alice@wonderland.lit/tea" subscription="subscribed"/>
            </pubsub>
          </iq>
        })
    end

    let(:pubsub) { MiniTest::Mock.new }

    before do
      pubsub.expect :node?, true, ['game_13']
      pubsub.expect :subscribed?, false, ['game_13', alice.jid]
      pubsub.expect :subscribe, nil, ['game_13', alice.jid]
    end

    it 'writes a result stanza to the stream' do
      subject.stub :pubsub, pubsub do
        subject.process
      end

      stream.verify
      pubsub.verify
      stream.nodes.size.must_equal 1
      stream.nodes.first.must_equal expected
    end
  end
end
