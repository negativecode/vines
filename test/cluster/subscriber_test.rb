# encoding: UTF-8

require 'test_helper'

class ClusterSubscriberTest < MiniTest::Unit::TestCase
  def setup
    @connection = MiniTest::Mock.new
    @cluster = MiniTest::Mock.new
    @cluster.expect(:id, 'abc')
  end

  def test_subscribe
    @cluster.expect(:connect, @connection)
    @connection.expect(:subscribe, nil, ['cluster:nodes:all'])
    @connection.expect(:subscribe, nil, ['cluster:nodes:abc'])
    @connection.expect(:on, nil, [:message])
    subscriber = Vines::Cluster::Subscriber.new(@cluster)
    subscriber.subscribe
    assert @connection.verify
    assert @cluster.verify
  end

  def test_heartbeat
    now = Time.now.to_i
    msg = {from: 'node-42', type: 'heartbeat', time: now}.to_json
    @cluster.expect(:poke, nil, ['node-42', now])

    subscriber = Vines::Cluster::Subscriber.new(@cluster)
    subscriber.send(:on_message, 'cluster:nodes:all', msg)
    assert @connection.verify
    assert @cluster.verify
  end

  def test_online
    now = Time.now.to_i
    msg = {from: 'node-42', type: 'online', time: now}.to_json
    @cluster.expect(:poke, nil, ['node-42', now])

    subscriber = Vines::Cluster::Subscriber.new(@cluster)
    subscriber.send(:on_message, 'cluster:nodes:all', msg)
    assert @connection.verify
    assert @cluster.verify
  end

  def test_offline
    now = Time.now.to_i
    msg = {from: 'node-42', type: 'offline', time: now}.to_json
    @cluster.expect(:delete_sessions, nil, ['node-42'])

    subscriber = Vines::Cluster::Subscriber.new(@cluster)
    subscriber.send(:on_message, 'cluster:nodes:all', msg)
    assert @connection.verify
    assert @cluster.verify
  end

  def test_route_stanza
    stanza = "<message to='alice@wonderland.lit/tea'>hello</message>"
    node = Nokogiri::XML(stanza).root rescue nil
    msg = {from: 'node-42', type: 'stanza', stanza: stanza}.to_json

    stream = MiniTest::Mock.new
    stream.expect(:write, nil, [node])
    @cluster.expect(:connected_resources, [stream], ['alice@wonderland.lit/tea'])

    subscriber = Vines::Cluster::Subscriber.new(@cluster)
    subscriber.send(:on_message, 'cluster:nodes:abc', msg)
    assert stream.verify
    assert @connection.verify
    assert @cluster.verify
  end

  def test_update_user
    alice = Vines::User.new(jid: 'alice@wonderland.lit/tea')
    msg = {from: 'node-42', type: 'user', jid: alice.jid.to_s}.to_json

    storage = MiniTest::Mock.new
    storage.expect(:find_user, alice, [alice.jid.bare])

    stream = MiniTest::Mock.new
    stream.expect(:user, alice)

    @cluster.expect(:storage, storage, ['wonderland.lit'])
    @cluster.expect(:connected_resources, [stream], [alice.jid.bare])

    subscriber = Vines::Cluster::Subscriber.new(@cluster)
    subscriber.send(:on_message, 'cluster:nodes:abc', msg)
    assert storage.verify
    assert stream.verify
    assert @connection.verify
    assert @cluster.verify
  end
end
