# encoding: UTF-8

require 'storage_tests'
require 'vines'
require 'minitest/autorun'

class MockRiak
  def initialize
    @buckets = {}
  end

  def bucket(id)
    @buckets[id] ||= MockRiakBucket.new
  end

  def flush_riak
    @buckets = {}
  end
end

class MockRiakBucket
  def initialize
    @data = HashWithIndifferentAccess.new
  end

  def new(id)
    @data[id] = MockRiakItem.new
  end

  def [](id)
    @data[id]
  end
end

class MockRiakItem
  attr_accessor :content_type, :data

  def initialize
  end

  def store
    @data = HashWithIndifferentAccess.new(@data)
  end
end

class RiakTest < MiniTest::Unit::TestCase
  include StorageTests

  MOCK_RIAK = MockRiak.new

  def setup
    EMLoop.new do
      db = MOCK_RIAK
      user_bucket = db.bucket('user')
      roster_bucket = db.bucket('roster')
      vcard_bucket = db.bucket('vcard')
      fragment_bucket = db.bucket('fragment')

      user = user_bucket.new('empty@wonderland.lit')
      user.content_type = 'application/json'
      user.data = {}
      user.store

      user = user_bucket.new('no_password@wonderland.lit')
      user.content_type = 'application/json'
      user.data = {'foo' => 'bar'}
      user.store

      user = user_bucket.new('clear_password@wonderland.lit')
      user.content_type = 'application/json'
      user.data = {'password' => 'secret'}
      user.store

      user = user_bucket.new('bcrypt_password@wonderland.lit')
      user.content_type = 'application/json'
      user.data = {'password' => BCrypt::Password.create('secret')}
      user.store

      user = user_bucket.new('full@wonderland.lit')
      user.content_type = 'application/json'
      user.data = {
        'password' => BCrypt::Password.create('secret'),
        'name' => 'Tester'
      }
      user.store

      user = user_bucket.new('full@wonderland.lit')
      user.content_type = 'application/json'
      user.data = {
        'password' => BCrypt::Password.create('secret'),
        'name' => 'Tester'
      }
      user.store

      roster = roster_bucket.new('full@wonderland.lit')
      roster.content_type = 'application/json'
      roster.data = {
        'contact1@wonderland.lit' => {'name' => 'Contact1', 'groups' => %w[Group1 Group2]},
        'contact2@wonderland.lit' => {'name' => 'Contact2', 'groups' => %w[Group3 Group4]}
      }
      roster.store

      vcard = vcard_bucket.new('full@wonderland.lit')
      vcard.content_type = 'application/json'
      vcard.data = {'card' => VCARD.to_xml}
      vcard.store

      fragment = fragment_bucket.new("full@wonderland.lit:#{FRAGMENT_ID}")
      fragment.content_type = 'application/json'
      fragment.data = {'xml' => FRAGMENT.to_xml}
      fragment.store
    end
  end

  def teardown
    MOCK_RIAK.flush_riak
  end

  def storage
    storage = Vines::Storage::Riak.new do
      nodes [ {:host => '127.0.0.1'} ]
    end
    def storage.riak; RiakTest::MOCK_RIAK; end
    storage
  end

  def test_init_raises_no_errors
    EMLoop.new do
      assert_raises(RuntimeError) { Vines::Storage::Riak.new {} }
      Vines::Storage::Riak.new do
        nodes [ {:host => '127.0.0.1'} ]
      end
    end
  end
end
