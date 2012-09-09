# encoding: UTF-8

require 'test_helper'

describe Vines::Stanza::PubSub::Create do
  subject      { Vines::Stanza::PubSub::Create.new(xml, stream) }
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
    let(:xml) { create('') }

    it 'raises a feature-not-implemented stanza error' do
      stream.expect :domain, 'wonderland.lit'
      -> { subject.process }.must_raise Vines::StanzaErrors::FeatureNotImplemented
      stream.verify
    end
  end

  describe 'when addressed to bare server domain' do
    let(:xml) { create('wonderland.lit') }

    it 'raises a feature-not-implemented stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::FeatureNotImplemented
      stream.verify
    end
  end

  describe 'when addressed to a non-pubsub component' do
    let(:router) { MiniTest::Mock.new }
    let(:xml) { create('bogus.wonderland.lit') }

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

  describe 'when attempting to create multiple nodes' do
    let(:xml) { create('games.wonderland.lit', true) }

    it 'raises a bad-request stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::BadRequest
      stream.verify
    end
  end

  describe 'when attempting to create duplicate nodes' do
    let(:pubsub) { MiniTest::Mock.new }
    let(:xml) { create('games.wonderland.lit') }

    it 'raises a conflict stanza error' do
      pubsub.expect :node?, true, ['game_13']
      subject.stub :pubsub, pubsub do
        -> { subject.process }.must_raise Vines::StanzaErrors::Conflict
      end
      stream.verify
      pubsub.verify
    end
  end

  describe 'when given a valid stanza' do
    let(:xml) { create('games.wonderland.lit') }
    let(:expected) { result(user.jid, 'games.wonderland.lit') }

    it 'sends an iq result stanza to sender' do
      subject.process
      stream.nodes.size.must_equal 1
      stream.nodes.first.must_equal expected
      stream.verify
    end
  end

  private

  def create(to, multiple=false)
    extra_create = "<create node='game_14'/>" if multiple
    body = %Q{
      <pubsub xmlns='http://jabber.org/protocol/pubsub'>
        <create node='game_13'/>
        #{extra_create}
      </pubsub>}
    iq(type: 'set', to: to, id: 42, body: body)
  end

  def result(to, from)
    body = '<pubsub xmlns="http://jabber.org/protocol/pubsub"><create node="game_13"/></pubsub>'
    iq(from: from, id: 42, to: to, type: 'result', body: body)
  end
end
