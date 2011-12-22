# encoding: UTF-8

require 'storage_tests'
require 'tmpdir'
require 'vines'
require 'minitest/autorun'

class LocalTest < MiniTest::Unit::TestCase
  include StorageTests

  DIR = Dir.mktmpdir

  def setup
    Dir.mkdir(DIR) unless File.exists?(DIR)
    %w[user vcard fragment].each do |d|
      Dir.mkdir(File.join(DIR, d))
    end

    files = {
      :empty      => "#{DIR}/user/empty@wonderland.lit",
      :no_pass    => "#{DIR}/user/no_password@wonderland.lit",
      :clear_pass => "#{DIR}/user/clear_password@wonderland.lit",
      :bcrypt     => "#{DIR}/user/bcrypt_password@wonderland.lit",
      :full       => "#{DIR}/user/full@wonderland.lit",
      :vcard      => "#{DIR}/vcard/full@wonderland.lit",
      :fragment   => "#{DIR}/fragment/full@wonderland.lit-#{FRAGMENT_ID}"
    }
    File.open(files[:empty], 'w') {|f| f.write('') }
    File.open(files[:no_pass], 'w') {|f| f.write('foo: bar') }
    File.open(files[:clear_pass], 'w') {|f| f.write('password: secret') }
    File.open(files[:bcrypt], 'w') {|f| f.write("password: #{BCrypt::Password.create('secret')}") }
    File.open(files[:full], 'w') do |f|
      f.puts("password: #{BCrypt::Password.create('secret')}")
      f.puts("name: Tester")
      f.puts("roster:")
      f.puts("  contact1@wonderland.lit:")
      f.puts("    name: Contact1")
      f.puts("    groups: [Group1, Group2]")
      f.puts("  contact2@wonderland.lit:")
      f.puts("    name: Contact2")
      f.puts("    groups: [Group3, Group4]")
    end
    File.open(files[:vcard], 'w') {|f| f.write(StorageTests::VCARD.to_xml) }
    File.open(files[:fragment], 'w') {|f| f.write(StorageTests::FRAGMENT.to_xml) }
  end

  def teardown
    FileUtils.remove_entry_secure(DIR)
  end

  def storage
    Vines::Storage::Local.new { dir DIR }
  end

  def test_init
    assert_raises(RuntimeError) { Vines::Storage::Local.new {} }
    assert_raises(RuntimeError) { Vines::Storage::Local.new { dir 'bogus' } }
    assert_raises(RuntimeError) { Vines::Storage::Local.new { dir '/sbin' } }
    Vines::Storage::Local.new { dir DIR } # shouldn't raise an error
  end
end
