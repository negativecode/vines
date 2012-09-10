# encoding: UTF-8

require 'test_helper'

describe Vines::Router do
  subject      { Vines::Router.new(config) }
  let(:alice)  { Vines::JID.new('alice@wonderland.lit/tea') }
  let(:hatter) { 'hatter@wonderland.lit/cake' }
  let(:romeo)  { 'romeo@verona.lit/party' }
  let(:config) do
    Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
        components 'tea' => 'secr3t'
      end
    end
  end

  describe '#connected_resources' do
    let(:cake) { 'alice@wonderland.lit/cake' }
    let(:stream1) { stream(alice) }
    let(:stream2) { stream(cake) }

    it 'is empty before any streams are connected' do
      subject.connected_resources(alice, alice).size.must_equal 0
      subject.connected_resources(cake, alice).size.must_equal 0
      subject.size.must_equal 0
    end

    it 'returns only one stream matching full jid' do
      subject << stream1
      subject << stream2

      streams = subject.connected_resources(alice, alice)
      streams.size.must_equal 1
      streams.first.user.jid.must_equal alice

      streams = subject.connected_resources(cake, alice)
      streams.size.must_equal 1
      streams.first.user.jid.to_s.must_equal cake
    end

    it 'returns all streams matching bare jid' do
      subject << stream1
      subject << stream2

      streams = subject.connected_resources(alice.bare, alice)
      streams.size.must_equal 2
      subject.size.must_equal 2
    end
  end

  describe '#connected_resources with permissions' do
    let(:stream1) { stream(alice) }
    let(:stream2) { stream(romeo) }

    before do
      subject << stream1
      subject << stream2
    end

    it 'denies access when cross domain messages is off' do
      subject.connected_resources(alice, romeo).size.must_equal 0
    end

    it 'allows access when cross domain messages is on' do
      config.vhost('wonderland.lit').cross_domain_messages true
      subject.connected_resources(alice, romeo).size.must_equal 1
    end
  end

  describe '#available_resources' do
    let(:cake) { 'alice@wonderland.lit/cake' }
    let(:stream1) { stream(alice) }
    let(:stream2) { stream(cake) }

    before do
      stream1.send 'available?=', true
      stream2.send 'available?=', false
    end

    it 'is empty before any streams are connected' do
      subject.available_resources(alice, alice).size.must_equal 0
      subject.available_resources(cake, alice).size.must_equal 0
      subject.size.must_equal 0
    end

    it 'returns available streams based on bare jid, not full jid' do
      subject << stream1
      subject << stream2

      streams = [alice, cake, alice.bare].map do |jid|
        subject.available_resources(jid, alice)
      end.flatten

      # should only have found alice's stream
      streams.size.must_equal 3
      streams.uniq.size.must_equal 1
      streams.first.user.jid.must_equal alice

      subject.size.must_equal 2
    end
  end

  describe '#interested_resources with no streams' do
    it 'is empty before any streams are connected' do
      subject.interested_resources(alice, alice).size.must_equal 0
      subject.interested_resources(hatter, alice).size.must_equal 0
      subject.interested_resources(alice, hatter, alice).size.must_equal 0
      subject.size.must_equal 0
    end
  end

  describe '#interested_resources' do
    let(:stream1) { stream(alice) }
    let(:stream2) { stream(hatter) }

    before do
      stream1.send 'interested?=', true
      stream2.send 'interested?=', false
      subject << stream1
      subject << stream2
    end

    it 'does not find streams for unauthenticated jids' do
      subject.interested_resources('bogus@wonderland.lit', alice).size.must_equal 0
    end

    it 'finds interested streams for full jids' do
      subject.interested_resources(alice, hatter, alice).size.must_equal 1
      subject.interested_resources([alice, hatter], alice).size.must_equal 1
      subject.interested_resources(alice, hatter, alice)[0].user.jid.must_equal alice
    end

    it 'does not find streams for uninterested jids' do
      subject.interested_resources(hatter, alice).size.must_equal 0
      subject.interested_resources([hatter], alice).size.must_equal 0
    end

    it 'finds interested streams for bare jids' do
      subject.interested_resources(alice.bare, alice).size.must_equal 1
      subject.interested_resources(alice.bare, alice)[0].user.jid.must_equal alice
    end
  end

  describe '#delete' do
    let(:stream1) { stream(alice) }
    let(:stream2) { stream(hatter) }

    it 'correctly adds and removes streams' do
      subject.size.must_equal 0

      subject << stream1
      subject << stream2
      subject.size.must_equal 2

      subject.delete(stream2)
      subject.size.must_equal 1

      subject.delete(stream2)
      subject.size.must_equal 1

      subject.delete(stream1)
      subject.size.must_equal 0
    end
  end

  describe 'load balanced component streams' do
    let(:stream1) { component('tea.wonderland.lit') }
    let(:stream2) { component('tea.wonderland.lit') }
    let(:stanza)  { node('<message from="alice@wonderland.lit" to="tea.wonderland.lit">test</message>')}

    before do
      subject << stream1
      subject << stream2
    end

    it 'must evenly distribute routed stanzas to both streams' do
      100.times { subject.route(stanza) }

      (stream1.count + stream2.count).must_equal 100
      stream1.count.must_be :>, 33
      stream2.count.must_be :>, 33
    end
  end

  describe 'load balanced s2s streams' do
    let(:stream1) { s2s('wonderland.lit', 'verona.lit') }
    let(:stream2) { s2s('wonderland.lit', 'verona.lit') }
    let(:stanza) { node('<message from="alice@wonderland.lit" to="romeo@verona.lit">test</message>') }

    before do
      config.vhost('wonderland.lit').cross_domain_messages true
      subject << stream1
      subject << stream2
    end

    it 'must evenly distribute routed stanzas to both streams' do
      100.times { subject.route(stanza) }

      (stream1.count + stream2.count).must_equal 100
      stream1.count.must_be :>, 33
      stream2.count.must_be :>, 33
    end
  end

  private

  def stream(jid)
    OpenStruct.new.tap do |stream|
      stream.send('connected?=', true)
      stream.stream_type = :client
      stream.user = Vines::User.new(jid: jid)
    end
  end

  def component(jid)
    OpenStruct.new.tap do |stream|
      stream.stream_type = :component
      stream.remote_domain = jid
      stream.send('ready?=', true)
      def stream.count; @count || 0; end
      def stream.write(stanza)
        @count ||= 0
        @count += 1
      end
    end
  end

  def s2s(domain, remote_domain)
    OpenStruct.new.tap do |stream|
      stream.stream_type = :server
      stream.domain = domain
      stream.remote_domain = remote_domain
      stream.send('ready?=', true)
      def stream.count; @count || 0; end
      def stream.write(stanza)
        @count ||= 0
        @count += 1
      end
    end
  end
end
