# encoding: UTF-8

require 'storage_tests'
require 'vines'
require 'test/unit'

class SqlTest < Test::Unit::TestCase
  include StorageTests

  DB_FILE = "./xmpp_testcase.db"
  ActiveRecord::Migration.verbose = false

  def setup
    storage.create_schema(:force => true)
    Vines::Storage::Sql::User.new(:jid => 'empty@wonderland.lit', :name => '', :password => '').save
    Vines::Storage::Sql::User.new(:jid => 'no_password@wonderland.lit', :name => '', :password => '').save
    Vines::Storage::Sql::User.new(:jid => 'clear_password@wonderland.lit', :name => '',
      :password => 'secret').save
    Vines::Storage::Sql::User.new(:jid => 'bcrypt_password@wonderland.lit', :name => '',
      :password => BCrypt::Password.create('secret')).save
    groups = %w[Group1 Group2 Group3 Group4].map do |name|
      Vines::Storage::Sql::Group.find_or_create_by_name(name)
    end
    full = Vines::Storage::Sql::User.new(
      :jid => 'full@wonderland.lit',
      :name => 'Tester',
      :password => BCrypt::Password.create('secret'),
      :vcard => StorageTests::VCARD.to_xml)
    full.contacts << Vines::Storage::Sql::Contact.new(
      :jid => 'contact1@wonderland.lit',
      :name => 'Contact1',
      :groups => groups[0, 2],
      :subscription => 'both')
    full.contacts << Vines::Storage::Sql::Contact.new(
      :jid => 'contact2@wonderland.lit',
      :name => 'Contact2',
      :groups => groups[2, 2],
      :subscription => 'both')
    full.save
  end

  def teardown
    File.delete(DB_FILE) if File.exist?(DB_FILE)
  end

  def storage
    Vines::Storage::Sql.new { adapter 'sqlite3'; database DB_FILE }
  end

  def test_init
    assert_raises(RuntimeError) { Vines::Storage::Sql.new {} }
    assert_raises(RuntimeError) { Vines::Storage::Sql.new { adapter 'postgresql' } }
    Vines::Storage::Sql.new { adapter 'sqlite3'; database ':memory:' } # shouldn't raise an error
  end
end
