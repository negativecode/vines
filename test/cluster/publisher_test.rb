# encoding: UTF-8

require 'test_helper'

class ClusterPublisherTest < MiniTest::Unit::TestCase
  def setup
    @connection = MiniTest::Mock.new
    @cluster = MiniTest::Mock.new
    @cluster.expect(:id, 'abc')
    @cluster.expect(:connection, @connection)
  end

  def test_broadcast
    msg = {from: 'abc', type: 'online', time: Time.now.to_i}.to_json
    @connection.expect(:publish, nil, ["cluster:nodes:all", msg])

    publisher = Vines::Cluster::Publisher.new(@cluster)
    publisher.broadcast(:online)
    assert @connection.verify
    assert @cluster.verify
  end

  def test_route
    stanza = "<message>hello</message>"
    msg = {from: 'abc', type: 'stanza', stanza: stanza}.to_json
    @connection.expect(:publish, nil, ["cluster:nodes:node-42", msg])

    publisher = Vines::Cluster::Publisher.new(@cluster)
    publisher.route(stanza, "node-42")
    assert @connection.verify
    assert @cluster.verify
  end

  def test_update_user
    jid = Vines::JID.new('alice@wonderland.lit')
    msg = {from: 'abc', type: 'user', jid: jid.to_s}.to_json
    @connection.expect(:publish, nil, ["cluster:nodes:node-42", msg])

    publisher = Vines::Cluster::Publisher.new(@cluster)
    publisher.update_user(jid, "node-42")
    assert @connection.verify
    assert @cluster.verify
  end
end
