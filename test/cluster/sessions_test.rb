# encoding: UTF-8

require 'vines'
require 'ext/nokogiri'
require 'storage/storage_tests'
require 'storage/mock_redis'
require 'minitest/autorun'

class ClusterSessionsTest < MiniTest::Unit::TestCase
  def setup
    @connection = MockRedis.new
    @cluster = MiniTest::Mock.new
    @cluster.expect(:connection, @connection)
  end

  def test_save
    StorageTests::EMLoop.new do
      @cluster.expect(:id, 'abc')
      jid1 = 'alice@wonderland.lit/tea'
      jid2 = 'alice@wonderland.lit/cake'
      sessions = Vines::Cluster::Sessions.new(@cluster)
      sessions.save(jid1, {available: true, interested: true})
      sessions.save(jid2, {available: false, interested: false})
      EM.next_tick do
        session1 = {node: 'abc', available: true, interested: true}
        session2 = {node: 'abc', available: false, interested: false}
        assert_equal 2, @connection.db["sessions:alice@wonderland.lit"].size
        assert_equal session1.to_json, @connection.db["sessions:alice@wonderland.lit"]['tea']
        assert_equal session2.to_json, @connection.db["sessions:alice@wonderland.lit"]['cake']
        assert_equal [jid1, jid2], @connection.db["cluster:nodes:abc"].to_a
        assert @cluster.verify
      end
    end
  end

  def test_delete
    StorageTests::EMLoop.new do
      jid1 = 'alice@wonderland.lit/tea'
      jid2 = 'alice@wonderland.lit/cake'
      @connection.db["sessions:alice@wonderland.lit"] = {}
      @connection.db["sessions:alice@wonderland.lit"]['tea'] = {node: 'abc', available: true}.to_json
      @connection.db["sessions:alice@wonderland.lit"]['cake'] = {node: 'abc', available: true}.to_json
      @connection.db["cluster:nodes:abc"] = Set.new([jid1, jid2])

      sessions = Vines::Cluster::Sessions.new(@cluster)
      sessions.delete(jid1)
      EM.next_tick do
        assert_equal 1, @connection.db["sessions:alice@wonderland.lit"].size
        assert_equal [jid2], @connection.db["cluster:nodes:abc"].to_a
        assert @cluster.verify
      end
    end
  end
end
