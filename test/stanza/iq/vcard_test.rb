# encoding: UTF-8

require 'test_helper'

describe Vines::Stanza::Iq::Vcard do
  subject       { Vines::Stanza::Iq::Vcard.new(xml, stream) }
  let(:alice)   { Vines::User.new(jid: 'alice@wonderland.lit/tea') }
  let(:stream)  { MiniTest::Mock.new }
  let(:storage) { MiniTest::Mock.new }
  let(:config) do
    Vines::Config.new do
      host 'wonderland.lit' do
        cross_domain_messages true
        storage(:fs) { dir Dir.tmpdir }
      end
    end
  end

  before do
    class << stream
      attr_accessor :config, :domain, :user
    end
    stream.config = config
    stream.domain = 'wonderland.lit'
    stream.user = alice
  end

  describe 'when getting vcard' do
    describe 'and addressed to a remote jid' do
      let(:xml) { get('romeo@verona.lit') }
      let(:router) { MiniTest::Mock.new }

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

    describe 'and missing to address' do
      let(:xml) { get('') }
      let(:card) { vcard('Alice') }
      let(:expected) { result(alice.jid, '', card) }

      before do
        storage.expect :find_vcard, card, [alice.jid.bare]
        stream.expect :storage, storage, ['wonderland.lit']
        stream.expect :write, nil, [expected]
      end

      it 'sends vcard for authenticated jid' do
        subject.process
        stream.verify
        storage.verify
      end
    end

    describe 'for another user' do
      let(:xml) { get(hatter) }
      let(:card) { vcard('Hatter') }
      let(:hatter) { Vines::JID.new('hatter@wonderland.lit') }
      let(:expected) { result(alice.jid, hatter, card) }

      before do
        storage.expect :find_vcard, card, [hatter]
        stream.expect :storage, storage, ['wonderland.lit']
        stream.expect :write, nil, [expected]
      end

      it 'succeeds and returns vcard with from address' do
        subject.process
        stream.verify
        storage.verify
      end
    end

    describe 'for missing vcard' do
      let(:xml) { get('') }

      before do
        storage.expect :find_vcard, nil, [alice.jid.bare]
        stream.expect :storage, storage, ['wonderland.lit']
      end

      it 'returns an item-not-found stanza error' do
        -> { subject.process }.must_raise Vines::StanzaErrors::ItemNotFound
        stream.verify
        storage.verify
      end
    end
  end

  describe 'when setting vcard' do
    describe 'and addressed to another user' do
      let(:xml) { set('hatter@wonderland.lit') }

      it 'raises a forbidden stanza error' do
        -> { subject.process }.must_raise Vines::StanzaErrors::Forbidden
        stream.verify
      end
    end

    describe 'and missing to address' do
      let(:xml) { set('') }
      let(:card) { vcard('Alice') }
      let(:expected) { result(alice.jid) }

      before do
        storage.expect :save_vcard, nil, [alice.jid, card]
        stream.expect :storage, storage, ['wonderland.lit']
        stream.expect :write, nil, [expected]
      end

      it 'succeeds and returns an iq result' do
        subject.process
        stream.verify
        storage.verify
      end
    end
  end

  private

  def vcard(name)
    node(%Q{<vCard xmlns="vcard-temp"><FN>#{name}</FN></vCard>})
  end

  def get(to)
    card = '<vCard xmlns="vcard-temp"/>'
    iq(id: 42, to: to, type: 'get', body: card)
  end

  def set(to)
    card = '<vCard xmlns="vcard-temp"><FN>Alice</FN></vCard>'
    iq(id: 42, to: to, type: 'set', body: card)
  end

  def result(to, from=nil, card=nil)
    iq(from: from, id: 42, to: to, type: 'result', body: card)
  end
end
