# encoding: UTF-8

require 'storage_tests'
require 'vines'
require 'minitest/autorun'

class LocalTest < MiniTest::Unit::TestCase
  include StorageTests

  def setup
    @files = {
      :empty      => './empty@wonderland.lit.user',
      :no_pass    => './no_password@wonderland.lit.user',
      :clear_pass => './clear_password@wonderland.lit.user',
      :bcrypt     => './bcrypt_password@wonderland.lit.user',
      :full       => './full@wonderland.lit.user',
      :vcard      => './full@wonderland.lit.vcard'
    }
    File.open(@files[:empty], 'w') {|f| f.write('') }
    File.open(@files[:no_pass], 'w') {|f| f.write('foo: bar') }
    File.open(@files[:clear_pass], 'w') {|f| f.write('password: secret') }
    File.open(@files[:bcrypt], 'w') {|f| f.write("password: #{BCrypt::Password.create('secret')}") }
    File.open(@files[:full], 'w') do |f|
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
    File.open(@files[:vcard], 'w') {|f| f.write(StorageTests::VCARD.to_xml) }
  end

  def teardown
    misc = %w[user vcard].map {|ext| "./save_user@domain.tld.#{ext}" }
    [*misc, *@files.values].each do |f|
      File.delete(f) if File.exist?(f)
    end
  end

  def storage
    Vines::Storage::Local.new { dir '.' }
  end

  def test_init
    assert_raises(RuntimeError) { Vines::Storage::Local.new {} }
    assert_raises(RuntimeError) { Vines::Storage::Local.new { dir 'bogus' } }
    assert_raises(RuntimeError) { Vines::Storage::Local.new { dir '/sbin' } }
    Vines::Storage::Local.new { dir '.' } # shouldn't raise an error
  end
end
