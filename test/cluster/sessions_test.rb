# encoding: UTF-8

require 'test_helper'
require 'storage/storage_tests'
require 'storage/mock_redis'

describe Vines::Cluster::Sessions do
  subject          { Vines::Cluster::Sessions.new(cluster) }
  let(:connection) { MockRedis.new }
  let(:cluster)    { OpenStruct.new(id: 'abc', connection: connection) }
  let(:jid1)       { 'alice@wonderland.lit/tea' }
  let(:jid2)       { 'alice@wonderland.lit/cake' }

  describe 'when saving to the cluster' do
    it 'writes to a redis hash' do
      StorageTests::EMLoop.new do
        subject.save(jid1, {available: true, interested: true})
        subject.save(jid2, {available: false, interested: false})
        EM.next_tick do
          session1 = {node: 'abc', available: true, interested: true}
          session2 = {node: 'abc', available: false, interested: false}
          connection.db["sessions:alice@wonderland.lit"].size.must_equal 2
          connection.db["sessions:alice@wonderland.lit"]['tea'].must_equal session1.to_json
          connection.db["sessions:alice@wonderland.lit"]['cake'].must_equal session2.to_json
          connection.db["cluster:nodes:abc"].to_a.must_equal [jid1, jid2]
        end
      end
    end
  end

  describe 'when deleting from the cluster' do
    it 'removes from a redis hash' do
      StorageTests::EMLoop.new do
        connection.db["sessions:alice@wonderland.lit"] = {}
        connection.db["sessions:alice@wonderland.lit"]['tea'] = {node: 'abc', available: true}.to_json
        connection.db["sessions:alice@wonderland.lit"]['cake'] = {node: 'abc', available: true}.to_json
        connection.db["cluster:nodes:abc"] = Set.new([jid1, jid2])

        subject.delete(jid1)
        EM.next_tick do
          connection.db["sessions:alice@wonderland.lit"].size.must_equal 1
          connection.db["cluster:nodes:abc"].to_a.must_equal [jid2]
        end
      end
    end
  end
end
