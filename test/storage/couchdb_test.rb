# encoding: UTF-8

require 'storage_tests'
require 'test_helper'

class CouchDBTest < MiniTest::Unit::TestCase
  include StorageTests

  URL = 'http://localhost:5984/xmpp_testcase'.freeze

  def setup
    EMLoop.new do
      database(:put)
      save_doc({'_id' => 'user:empty@wonderland.lit'})

      save_doc({
        '_id'  => 'user:no_password@wonderland.lit',
        'type' => 'User',
        'foo'  => 'bar'})

      save_doc({
        '_id'      => 'user:clear_password@wonderland.lit',
        'type'     => 'User',
        'password' => 'secret'})

      save_doc({
        '_id'      => 'user:bcrypt_password@wonderland.lit',
        'type'     => 'User',
        'password' => BCrypt::Password.create('secret')})

      save_doc({
        '_id'      => 'user:full@wonderland.lit',
        'type'     => 'User',
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

      save_doc({
        '_id'  => 'vcard:full@wonderland.lit',
        'type' => 'Vcard',
        'card' => VCARD.to_xml
      })

      save_doc({
        '_id'  => "fragment:full@wonderland.lit:#{FRAGMENT_ID}",
        'type' => 'Fragment',
        'xml'  => FRAGMENT.to_xml
      })
    end
  end

  def teardown
    EMLoop.new do
      database(:delete)
    end
  end

  def save_doc(doc)
    fiber = Fiber.current
    http = EM::HttpRequest.new(URL).post(
      :head => {'Content-Type' => 'application/json'},
      :body => doc.to_json)
    http.callback { fiber.resume }
    http.errback { raise 'save_doc failed' }
    Fiber.yield
  end

  def database(method=:put)
    fiber = Fiber.current
    http = EM::HttpRequest.new(URL).send(method)
    http.callback { fiber.resume }
    http.errback { raise "#{method} database failed" }
    Fiber.yield
  end

  def storage
    Vines::Storage::CouchDB.new do
      host 'localhost'
      port 5984
      database 'xmpp_testcase'
    end
  end

  def test_init
    EMLoop.new do
      assert_raises(RuntimeError) { Vines::Storage::CouchDB.new {} }
      assert_raises(RuntimeError) { Vines::Storage::CouchDB.new { host 'localhost' } }
      # shouldn't raise an error
      Vines::Storage::CouchDB.new do
        host 'localhost'
        port '5984'
        database 'test'
      end
    end
  end
end
