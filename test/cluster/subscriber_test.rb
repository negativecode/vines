# encoding: UTF-8

require 'test_helper'

describe Vines::Cluster::Subscriber do
  subject          { Vines::Cluster::Subscriber.new(cluster) }
  let(:connection) { MiniTest::Mock.new }
  let(:cluster)    { MiniTest::Mock.new }
  let(:now)        { Time.now.to_i }

  before do
    cluster.expect :id, 'abc'
  end

  describe '#subscribe' do
    before do
      cluster.expect :connect, connection
      connection.expect :subscribe, nil, ['cluster:nodes:all']
      connection.expect :subscribe, nil, ['cluster:nodes:abc']
      connection.expect :on, nil, [:message]
    end

    it 'subscribes to its own channel and the broadcast channel' do
      subject.subscribe
      connection.verify
      cluster.verify
    end
  end

  describe 'when receiving a heartbeat broadcast message' do
    before do
      cluster.expect :poke, nil, ['node-42', now]
    end

    it 'pokes the session manager for the broadcasting node' do
      msg = {from: 'node-42', type: 'heartbeat', time: now}.to_json
      subject.send(:on_message, 'cluster:nodes:all', msg)
      connection.verify
      cluster.verify
    end
  end

  describe 'when receiving an initial online broadcast message' do
    before do
      cluster.expect :poke, nil, ['node-42', now]
    end

    it 'pokes the session manager for the broadcasting node' do
      msg = {from: 'node-42', type: 'online', time: now}.to_json
      subject.send(:on_message, 'cluster:nodes:all', msg)
      connection.verify
      cluster.verify
    end
  end

  describe 'when receiving an offline broadcast message' do
    before do
      cluster.expect :delete_sessions, nil, ['node-42']
    end

    it 'deletes the sessions for the broadcasting node' do
      msg = {from: 'node-42', type: 'offline', time: now}.to_json
      subject.send(:on_message, 'cluster:nodes:all', msg)
      connection.verify
      cluster.verify
    end
  end

  describe 'when receiving a stanza routed to my node' do
    let(:stream) { MiniTest::Mock.new }
    let(:stanza) { "<message to='alice@wonderland.lit/tea'>hello</message>" }
    let(:xml) { Nokogiri::XML(stanza).root }

    before do
      stream.expect :write, nil, [xml]
      cluster.expect :connected_resources, [stream], ['alice@wonderland.lit/tea']
    end

    it 'writes the stanza to the connected user streams' do
      msg = {from: 'node-42', type: 'stanza', stanza: stanza}.to_json
      subject.send(:on_message, 'cluster:nodes:abc', msg)
      stream.verify
      connection.verify
      cluster.verify
    end
  end

  describe 'when receiving a user update message to my node' do
    let(:alice) { Vines::User.new(jid: 'alice@wonderland.lit/tea') }
    let(:storage) { MiniTest::Mock.new }
    let(:stream) { MiniTest::Mock.new }

    before do
      storage.expect :find_user, alice, [alice.jid.bare]
      stream.expect :user, alice
      cluster.expect :storage, storage, ['wonderland.lit']
      cluster.expect :connected_resources, [stream], [alice.jid.bare]
    end

    it 'reloads the user from storage and updates their connected streams' do
      msg = {from: 'node-42', type: 'user', jid: alice.jid.to_s}.to_json
      subject.send(:on_message, 'cluster:nodes:abc', msg)
      storage.verify
      stream.verify
      connection.verify
      cluster.verify
    end
  end
end
