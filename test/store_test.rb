# encoding: UTF-8

require 'test_helper'

describe Vines::Store do
  let(:dir) { 'conf/certs' }
  subject { Vines::Store.new(dir) }

  before do
    domain, key = certificate('wonderland.lit')
    File.open("#{dir}/wonderland.lit.crt", 'w') {|f| f.write(domain) }
    File.open("#{dir}/wonderland.lit.key", 'w') {|f| f.write(key) }

    wildcard, key = certificate('*.wonderland.lit')
    File.open("#{dir}/wildcard.lit.crt", 'w') {|f| f.write(wildcard) }
    File.open("#{dir}/wildcard.lit.key", 'w') {|f| f.write(key) }
  end

  after do
    %w[wonderland.lit.crt wonderland.lit.key wildcard.lit.crt wildcard.lit.key].each do |f|
      name = "#{dir}/#{f}"
      File.delete(name) if File.exists?(name)
    end
  end

  it 'parses certificate files' do
    refute subject.certs.empty?
    assert_equal OpenSSL::X509::Certificate, subject.certs.first.class
  end

  it 'ignores expired certificates' do
    assert subject.certs.all? {|c| c.not_after > Time.new }
  end

  describe 'files_for_domain' do
    it 'handles invalid input' do
      assert_nil subject.files_for_domain(nil)
      assert_nil subject.files_for_domain('')
    end

    it 'finds files by name' do
      refute_nil subject.files_for_domain('wonderland.lit')
      cert, key = subject.files_for_domain('wonderland.lit')
      assert_certificate_matches_key cert, key
      assert_equal 'wonderland.lit.crt', File.basename(cert)
      assert_equal 'wonderland.lit.key', File.basename(key)
    end

    it 'finds files for wildcard' do
      refute_nil subject.files_for_domain('foo.wonderland.lit')
      cert, key = subject.files_for_domain('foo.wonderland.lit')
      assert_certificate_matches_key cert, key
      assert_equal 'wildcard.lit.crt', File.basename(cert)
      assert_equal 'wildcard.lit.key', File.basename(key)
    end
  end

  describe 'domain?' do
    it 'handles invalid input' do
      cert, key = certificate('wonderland.lit')
      refute subject.domain?(nil, nil)
      refute subject.domain?(cert, nil)
      refute subject.domain?(cert, '')
      refute subject.domain?(nil, '')
      assert subject.domain?(cert, 'wonderland.lit')
    end

    it 'verifies certificate subject domains' do
      cert, key = certificate('wonderland.lit')
      refute subject.domain?(cert, 'bogus')
      refute subject.domain?(cert, 'www.wonderland.lit')
      assert subject.domain?(cert, 'wonderland.lit')
    end

    it 'verifies certificate subject alt domains' do
      cert, key = certificate('wonderland.lit', 'www.wonderland.lit')
      refute subject.domain?(cert, 'bogus')
      refute subject.domain?(cert, 'tea.wonderland.lit')
      assert subject.domain?(cert, 'www.wonderland.lit')
      assert subject.domain?(cert, 'wonderland.lit')
    end

    it 'verifies certificate wildcard domains' do
      cert, key = certificate('wonderland.lit', '*.wonderland.lit')
      refute subject.domain?(cert, 'bogus')
      refute subject.domain?(cert, 'one.two.wonderland.lit')
      assert subject.domain?(cert, 'tea.wonderland.lit')
      assert subject.domain?(cert, 'www.wonderland.lit')
      assert subject.domain?(cert, 'wonderland.lit')
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
    # Use small key so tests are fast.
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
