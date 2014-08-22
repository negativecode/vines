# encoding: UTF-8

require 'test_helper'

describe Vines::Store do
  let(:dir) { 'conf/certs' }
  let(:domain_pair) { certificate('wonderland.lit') }
  let(:wildcard_pair) { certificate('*.wonderland.lit') }
  subject { Vines::Store.new(dir) }

  before do
    @files =
      save('wonderland.lit', domain_pair) +
      save('wildcard.lit', wildcard_pair) +
      save('duplicate.lit', domain_pair)
  end

  after do
    @files.each do |name|
      File.delete(name) if File.exists?(name)
    end
  end

  describe 'creating a store' do
    it 'parses certificate files' do
      refute subject.certs.empty?
      assert_equal OpenSSL::X509::Certificate, subject.certs.first.class
    end

    it 'ignores expired certificates' do
      assert subject.certs.all? {|c| c.not_after > Time.new }
    end

    it 'does not raise an error for duplicate certificates' do
      assert Vines::Store.new(dir)
    end
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

  describe 'trusted?' do
    it 'does not trust malformed certificates' do
      refute subject.trusted?('bogus')
    end

    it 'does not trust unsigned certificates' do
      pair = certificate('something.lit')
      refute subject.trusted?(pair.cert)
    end
  end

  describe 'domain?' do
    it 'handles invalid input' do
      pair = certificate('wonderland.lit')
      refute subject.domain?(nil, nil)
      refute subject.domain?(pair.cert, nil)
      refute subject.domain?(pair.cert, '')
      refute subject.domain?(nil, '')
      assert subject.domain?(pair.cert, 'wonderland.lit')
    end

    it 'verifies certificate subject domains' do
      pair = certificate('wonderland.lit')
      refute subject.domain?(pair.cert, 'bogus')
      refute subject.domain?(pair.cert, 'www.wonderland.lit')
      assert subject.domain?(pair.cert, 'wonderland.lit')
    end

    it 'verifies certificate subject alt domains' do
      pair = certificate('wonderland.lit', 'www.wonderland.lit')
      refute subject.domain?(pair.cert, 'bogus')
      refute subject.domain?(pair.cert, 'tea.wonderland.lit')
      assert subject.domain?(pair.cert, 'www.wonderland.lit')
      assert subject.domain?(pair.cert, 'wonderland.lit')
    end

    it 'verifies certificate wildcard domains' do
      pair = certificate('wonderland.lit', '*.wonderland.lit')
      refute subject.domain?(pair.cert, 'bogus')
      refute subject.domain?(pair.cert, 'one.two.wonderland.lit')
      assert subject.domain?(pair.cert, 'tea.wonderland.lit')
      assert subject.domain?(pair.cert, 'www.wonderland.lit')
      assert subject.domain?(pair.cert, 'wonderland.lit')
    end
  end

  private

  # A public certificate + private key pair.
  Pair = Struct.new(:cert, :key)

  def assert_certificate_matches_key(cert, key)
    refute_nil cert
    refute_nil key
    cert = OpenSSL::X509::Certificate.new(File.read(cert))
    key = OpenSSL::PKey::RSA.new(File.read(key))
    assert_equal cert.public_key.to_s, key.public_key.to_s
  end

  def certificate(domain, altname=nil)
    # Use small key so tests are fast.
    key = OpenSSL::PKey::RSA.generate(512)

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

    cert.sign key, OpenSSL::Digest::SHA1.new

    Pair.new(cert.to_pem, key.to_pem)
  end

  # Write the domain's certificate and private key files to the filesystem for
  # the store to use.
  #
  # domain - The domain name String to use in the file name (e.g. wonderland.lit).
  # pair   - The Pair containing the public certificate and private key data.
  #
  # Returns a String Array of file names that were written.
  def save(domain, pair)
    crt = File.expand_path("#{domain}.crt", dir)
    key = File.expand_path("#{domain}.key", dir)
    File.open(crt, 'w') {|f| f.write(pair.cert) }
    File.open(key, 'w') {|f| f.write(pair.key) }
    [crt, key]
  end
end
