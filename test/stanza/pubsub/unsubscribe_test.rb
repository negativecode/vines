# encoding: UTF-8

require 'test_helper'

describe Vines::Stanza::PubSub::Unsubscribe do
  subject      { Vines::Stanza::PubSub::Unsubscribe.new(xml, stream) }
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
    let(:xml) { unsubscribe('') }

    it 'raises a feature-not-implemented stanza error' do
      stream.expect :domain, 'wonderland.lit'
      -> { subject.process }.must_raise Vines::StanzaErrors::FeatureNotImplemented
      stream.verify
    end
  end

  describe 'when addressed to bare server domain' do
    let(:xml) { unsubscribe('wonderland.lit') }

    it 'raises a feature-not-implemented stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::FeatureNotImplemented
      stream.verify
    end
  end

  describe 'when addressed to a non-pubsub component' do
    let(:router) { MiniTest::Mock.new }
    let(:xml) { unsubscribe('bogus.wonderland.lit') }

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

  describe 'when attempting to unsubscribe from multiple nodes' do
    let(:xml) { unsubscribe('games.wonderland.lit', true) }

    it 'raises a bad-request stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::BadRequest
      stream.verify
    end
  end

  describe 'when unsubscribing from a missing node' do
    let(:xml) { unsubscribe('games.wonderland.lit') }

    it 'raises an item-not-found stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::ItemNotFound
      stream.verify
    end
  end

  describe 'when unsubscribing without a subscription' do
    let(:pubsub) { MiniTest::Mock.new }
    let(:xml) { unsubscribe('games.wonderland.lit') }

    before do
      pubsub.expect :node?, true, ['game_13']
      pubsub.expect :subscribed?, false, ['game_13', user.jid]
    end

    it 'raises an unexpected-request stanza error' do
      subject.stub :pubsub, pubsub do
        -> { subject.process }.must_raise Vines::StanzaErrors::UnexpectedRequest
      end
      stream.verify
      pubsub.verify
    end
  end

  describe 'when unsubscribing an illegal jid' do
    let(:xml) { unsubscribe('games.wonderland.lit', false, 'not_alice@wonderland.lit/tea') }

    it 'raises a forbidden stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::Forbidden
      stream.verify
    end
  end

  describe 'when given a valid stanza' do
    let(:pubsub) { MiniTest::Mock.new }
    let(:xml) { unsubscribe('games.wonderland.lit') }
    let(:expected) { result(user.jid, 'games.wonderland.lit') }

    before do
      pubsub.expect :node?, true, ['game_13']
      pubsub.expect :subscribed?, true, ['game_13', user.jid]
      pubsub.expect :unsubscribe, nil, ['game_13', user.jid]
    end

    it 'sends an iq result stanza to sender' do
      subject.stub :pubsub, pubsub do
        subject.process
      end

      stream.nodes.size.must_equal 1
      stream.nodes.first.must_equal expected
      stream.verify
      pubsub.verify
    end
  end

  private

  def unsubscribe(to, multiple=false, jid=user.jid)
    extra = "<unsubscribe node='game_14' jid='#{jid}'/>" if multiple
    body = %Q{
      <pubsub xmlns='http://jabber.org/protocol/pubsub'>
        <unsubscribe node='game_13' jid="#{jid}"/>
        #{extra}
      </pubsub>}
    iq(type: 'set', to: to, id: 42, body: body)
  end

  def result(to, from)
    iq(from: from, id: 42, to: to, type: 'result')
  end
end
