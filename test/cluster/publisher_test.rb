# encoding: UTF-8

require 'test_helper'

describe Vines::Cluster::Publisher do
  subject          { Vines::Cluster::Publisher.new(cluster) }
  let(:connection) { MiniTest::Mock.new }
  let(:cluster)    { MiniTest::Mock.new }

  before do
    cluster.expect :id, 'abc'
    cluster.expect :connection, connection
  end

  describe '#broadcast' do
    before do
      msg = {from: 'abc', type: 'online', time: Time.now.to_i}.to_json
      connection.expect :publish, nil, ["cluster:nodes:all", msg]
    end

    it 'publishes the message to every cluster node' do
      subject.broadcast(:online)
      connection.verify
      cluster.verify
    end
  end

  describe '#route' do
    let(:stanza) { "<message>hello</message>" }

    before do
      msg = {from: 'abc', type: 'stanza', stanza: stanza}.to_json
      connection.expect :publish, nil, ["cluster:nodes:node-42", msg]
    end

    it 'publishes the message to just one cluster node' do
      subject.route(stanza, "node-42")
      connection.verify
      cluster.verify
    end
  end

  describe '#update_user' do
    let(:jid) { Vines::JID.new('alice@wonderland.lit') }

    before do
      msg = {from: 'abc', type: 'user', jid: jid.to_s}.to_json
      connection.expect :publish, nil, ["cluster:nodes:node-42", msg]
    end

    it 'publishes the new user to just one cluster node' do
      subject.update_user(jid, "node-42")
      connection.verify
      cluster.verify
    end
  end
end
