# encoding: UTF-8

require 'mock_mongo'
require 'storage_tests'
require 'vines'
require 'minitest/autorun'

class MongoDBTest < MiniTest::Unit::TestCase
  include StorageTests

  MOCK_MONGO = MockMongo.new

  def setup
    EMLoop.new do
      db = MOCK_MONGO
      db.collection(:users).save({'_id' => 'empty@wonderland.lit'})
      db.collection(:users).save({'_id' => 'no_password@wonderland.lit', 'foo' => 'bar'})
      db.collection(:users).save({'_id' => 'clear_password@wonderland.lit', 'password' => 'secret'})
      db.collection(:users).save({'_id' => 'bcrypt_password@wonderland.lit', 'password' => BCrypt::Password.create('secret')})
      db.collection(:users).save({
        '_id'      => 'full@wonderland.lit',
        'password' => BCrypt::Password.create('secret'),
        'name'     => 'Tester',
        'roster'   => {
          'contact1@wonderland.lit' => {
            'name'   => 'Contact1',
            'groups' => %w[Group1 Group2]
          },
          'contact2@wonderland.lit' => {
            'name'   => 'Contact2',
            'groups' => %w[Group3 Group4]
          }
        }
      })
      db.collection(:vcards).save({'_id' => 'full@wonderland.lit', 'card' => VCARD.to_xml})
      db.collection(:fragments).save({'_id' => "full@wonderland.lit:#{FRAGMENT_ID}", 'xml' => FRAGMENT.to_xml})
    end
  end

  def teardown
    MOCK_MONGO.clear
  end

  def storage
    storage = Vines::Storage::MongoDB.new do
      host 'localhost'
      port 27017
      database 'xmpp_testcase'
    end
    def storage.db
      MongoDBTest::MOCK_MONGO
    end
    storage
  end

  def test_init
    EMLoop.new do
      assert_raises(RuntimeError) { Vines::Storage::MongoDB.new {} }
      assert_raises(RuntimeError) { Vines::Storage::MongoDB.new { host 'localhost' } }
      # shouldn't raise an error
      Vines::Storage::MongoDB.new do
        host 'localhost'
        port '27017'
        database 'test'
      end
    end
  end
end
