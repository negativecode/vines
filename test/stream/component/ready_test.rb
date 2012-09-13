# encoding: UTF-8

require 'test_helper'

describe Vines::Stream::Component::Ready do
  subject      { Vines::Stream::Component::Ready.new(stream, nil) }
  let(:alice)  { Vines::User.new(jid: 'alice@tea.wonderland.lit') }
  let(:hatter) { Vines::User.new(jid: 'hatter@wonderland.lit') }
  let(:stream) { MiniTest::Mock.new }
  let(:config) do
    Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
      end
    end
  end

  before do
    class << stream
      attr_accessor :config
    end
    stream.config = config
  end

  describe 'when missing to and from addresses' do
    it 'raises an improper-addressing stream error' do
      node = node('<message/>')
      -> { subject.node(node) }.must_raise Vines::StreamErrors::ImproperAddressing
      stream.verify
    end
  end

  describe 'when missing from address' do
    it 'raises an improper-addressing stream error' do
      node = node(%q{<message to="hatter@wonderland.lit"/>})
      -> { subject.node(node) }.must_raise Vines::StreamErrors::ImproperAddressing
      stream.verify
    end
  end

  describe 'when missing to address' do
    it 'raises an improper-addressing stream error' do
      node = node(%q{<message from="alice@tea.wonderland.lit"/>})
      -> { subject.node(node) }.must_raise Vines::StreamErrors::ImproperAddressing
      stream.verify
    end
  end

  describe 'when from address domain does not match component domain' do
    it 'raises and invalid-from stream error' do
      stream.expect :remote_domain, 'tea.wonderland.lit'
      node = node(%q{<message from="alice@bogus.wonderland.lit" to="hatter@wonderland.lit"/>})
      -> { subject.node(node) }.must_raise Vines::StreamErrors::InvalidFrom
      stream.verify
    end
  end

  describe 'when unrecognized element is received' do
    it 'raises an unsupported-stanza-type stream error' do
      node = node('<bogus/>')
      -> { subject.node(node) }.must_raise Vines::StreamErrors::UnsupportedStanzaType
      stream.verify
    end
  end

  describe 'when addressed to a remote jid' do
    let(:router) { MiniTest::Mock.new }
    let(:xml) { node(%q{<message from="alice@tea.wonderland.lit" to="romeo@verona.lit"/>}) }

    before do
      router.expect :route, nil, [xml]
      stream.expect :remote_domain, 'tea.wonderland.lit'
      stream.expect :user=, nil, [alice]
      stream.expect :router, router
    end

    it 'routes rather than handle locally' do
      subject.node(xml)
      stream.verify
      router.verify
    end
  end

  describe 'when addressed to a local jid' do
    let(:recipient) { MiniTest::Mock.new }
    let(:xml) { node(%q{<message from="alice@tea.wonderland.lit" to="hatter@wonderland.lit"/>}) }

    before do
      recipient.expect :user, hatter
      recipient.expect :write, nil, [xml]
      stream.expect :remote_domain, 'tea.wonderland.lit'
      stream.expect :user=, nil, [alice]
      stream.expect :user, alice
      stream.expect :connected_resources, [recipient], [hatter.jid]
    end

    it 'sends the message to the connected stream' do
      subject.node(xml)
      stream.verify
      recipient.verify
    end
  end
end
