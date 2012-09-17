# encoding: UTF-8

require 'test_helper'

describe Vines::Stanza::Message do
  subject      { Vines::Stanza::Message.new(xml, stream) }
  let(:stream) { MiniTest::Mock.new }
  let(:alice)  { Vines::User.new(jid: 'alice@wonderland.lit/tea') }
  let(:romeo)  { Vines::User.new(jid: 'romeo@verona.lit/balcony') }
  let(:config) do
    Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
      end
    end
  end

  before do
    class << stream
      attr_accessor :config, :user
    end
    stream.user = alice
    stream.config = config
  end

  describe 'when message type attribute is invalid' do
    let(:xml) { node('<message type="bogus">hello!</message>') }

    it 'raises a bad-request stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::BadRequest
    end
  end

  describe 'when the to address is missing' do
    let(:xml) { node('<message>hello!</message>') }
    let(:recipient) { MiniTest::Mock.new }

    before do
      recipient.expect :user, alice
      recipient.expect :write, nil, [xml]
      stream.expect :connected_resources, [recipient], [alice.jid.bare]
    end

    it 'sends the message to the senders connected streams' do
      subject.process
      stream.verify
      recipient.verify
    end
  end

  describe 'when addressed to a non-user' do
    let(:bogus) { Vines::JID.new('bogus@wonderland.lit/cake') }
    let(:xml) { node(%Q{<message to="#{bogus}">hello!</message>}) }
    let(:storage) { MiniTest::Mock.new }

    before do
      storage.expect :find_user, nil, [bogus]
      stream.expect :storage, storage, [bogus.domain]
      stream.expect :connected_resources, [], [bogus]
    end

    it 'ignores the stanza' do
      subject.process
      stream.verify
      storage.verify
    end
  end

  describe 'when addressed to an offline user' do
    let(:hatter) { Vines::User.new(jid: 'hatter@wonderland.lit/cake') }
    let(:xml) { node(%Q{<message to="#{hatter.jid}">hello!</message>}) }
    let(:storage) { MiniTest::Mock.new }

    before do
      storage.expect :find_user, hatter, [hatter.jid]
      stream.expect :storage, storage, [hatter.jid.domain]
      stream.expect :connected_resources, [], [hatter.jid]
    end

    it 'raises a service-unavailable stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::ServiceUnavailable
      stream.verify
      storage.verify
    end
  end

  describe 'when address to a local user in a different domain' do
    let(:xml) { node(%Q{<message to="#{romeo.jid}">hello!</message>}) }
    let(:expected) { node(%Q{<message to="#{romeo.jid}" from="#{alice.jid}">hello!</message>}) }
    let(:recipient) { MiniTest::Mock.new }

    before do
      recipient.expect :user, romeo
      recipient.expect :write, nil, [expected]

      config.host 'verona.lit' do
        storage(:fs) { dir Dir.tmpdir }
      end

      stream.expect :connected_resources, [recipient], [romeo.jid]
    end

    it 'delivers the stanza to the user' do
      subject.process
      stream.verify
      recipient.verify
    end
  end

  describe 'when addressed to a remote user' do
    let(:xml) { node(%Q{<message to="#{romeo.jid}">hello!</message>}) }
    let(:expected) { node(%Q{<message to="#{romeo.jid}" from="#{alice.jid}">hello!</message>}) }
    let(:router) { MiniTest::Mock.new }

    before do
      router.expect :route, nil, [expected]
      stream.expect :router, router
    end

    it 'routes rather than handle locally' do
      subject.process
      stream.verify
      router.verify
    end
  end
end
