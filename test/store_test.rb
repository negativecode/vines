# encoding: UTF-8

require 'vines'
require 'minitest/autorun'

describe Vines::Store do
  before do
    dir = 'conf/certs'

    domain, key = certificate('wonderland.lit')
    File.open("#{dir}/wonderland.lit.crt", 'w') {|f| f.write(domain) }
    File.open("#{dir}/wonderland.lit.key", 'w') {|f| f.write(key) }

    wildcard, key = certificate('*.wonderland.lit')
    File.open("#{dir}/wildcard.lit.crt", 'w') {|f| f.write(wildcard) }
    File.open("#{dir}/wildcard.lit.key", 'w') {|f| f.write(key) }

    @store = Vines::Store.new('conf/certs')
  end

  after do
    %w[wonderland.lit.crt wonderland.lit.key wildcard.lit.crt wildcard.lit.key].each do |f|
      name = "conf/certs/#{f}"
      File.delete(name) if File.exists?(name)
    end
  end

  it 'parses certificate files' do
    refute @store.certs.empty?
    assert_equal OpenSSL::X509::Certificate, @store.certs.first.class
  end

  it 'ignores expired certificates' do
    assert @store.certs.all? {|c| c.not_after > Time.new }
  end

  describe 'files_for_domain' do
    it 'handles invalid input' do
      assert_nil @store.files_for_domain(nil)
      assert_nil @store.files_for_domain('')
    end

    it 'finds files by name' do
      refute_nil @store.files_for_domain('wonderland.lit')
      cert, key = @store.files_for_domain('wonderland.lit')
      assert_certificate_matches_key cert, key
      assert_equal 'wonderland.lit.crt', File.basename(cert)
      assert_equal 'wonderland.lit.key', File.basename(key)
    end

    it 'finds files for wildcard' do
      refute_nil @store.files_for_domain('foo.wonderland.lit')
      cert, key = @store.files_for_domain('foo.wonderland.lit')
      assert_certificate_matches_key cert, key
      assert_equal 'wildcard.lit.crt', File.basename(cert)
      assert_equal 'wildcard.lit.key', File.basename(key)
    end
  end

  describe 'domain?' do
    it 'handles invalid input' do
      cert, key = certificate('wonderland.lit')
      refute @store.domain?(nil, nil)
      refute @store.domain?(cert, nil)
      refute @store.domain?(cert, '')
      refute @store.domain?(nil, '')
      assert @store.domain?(cert, 'wonderland.lit')
    end

    it 'verifies certificate subject domains' do
      cert, key = certificate('wonderland.lit')
      refute @store.domain?(cert, 'bogus')
      refute @store.domain?(cert, 'www.wonderland.lit')
      assert @store.domain?(cert, 'wonderland.lit')
    end

    it 'verifies certificate subject alt domains' do
      cert, key = certificate('wonderland.lit', 'www.wonderland.lit')
      refute @store.domain?(cert, 'bogus')
      refute @store.domain?(cert, 'tea.wonderland.lit')
      assert @store.domain?(cert, 'www.wonderland.lit')
      assert @store.domain?(cert, 'wonderland.lit')
    end

    it 'verifies certificate wildcard domains' do
      cert, key = certificate('wonderland.lit', '*.wonderland.lit')
      refute @store.domain?(cert, 'bogus')
      refute @store.domain?(cert, 'one.two.wonderland.lit')
      assert @store.domain?(cert, 'tea.wonderland.lit')
      assert @store.domain?(cert, 'www.wonderland.lit')
      assert @store.domain?(cert, 'wonderland.lit')
    end
  end

  private

  def assert_certificate_matches_key(cert, key)
    refute_nil cert
    refute_nil key
    cert = OpenSSL::X509::Certificate.new(File.read(cert))
    key = OpenSSL::PKey::RSA.new(File.read(key))
    assert_equal cert.public_key.to_s, key.public_key.to_s
  end

  def certificate(domain, altname=nil)
    # use small key so tests are fast
    key = OpenSSL::PKey::RSA.generate(256)

    name = OpenSSL::X509::Name.parse("/C=US/ST=Colorado/L=Denver/O=Test/CN=#{domain}")
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.subject = name
    cert.issuer = name
    cert.serial = Time.now.to_i
    cert.public_key = key.public_key
    cert.not_before = Time.now
    cert.not_after = Time.now + 3600

    if altname
      factory = OpenSSL::X509::ExtensionFactory.new
      factory.subject_certificate = cert
      factory.issuer_certificate = cert
      cert.extensions = [
        %w[subjectKeyIdentifier hash],
        %w[subjectAltName] << [domain, altname].map {|n| "DNS:#{n}" }.join(',')
      ].map {|k, v| factory.create_ext(k, v) }
    end

    [cert.to_pem, key.to_pem]
  end
end
