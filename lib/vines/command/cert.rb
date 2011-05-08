# encoding: UTF-8

module Vines
  module Command
    class Cert
      def run(opts)
        raise 'vines cert <domain>' unless opts[:args].size == 1
        dir = File.expand_path(File.join(opts[:config], '../certs'))
        create_cert(opts[:args].first, dir)
      end

      def create_cert(domain, dir)
        domain = domain.downcase
        key = OpenSSL::PKey::RSA.generate(2048)
        ca = OpenSSL::X509::Name.parse("/C=US/ST=Colorado/L=Denver/O=Vines XMPP Server/CN=#{domain}")
        cert = OpenSSL::X509::Certificate.new
        cert.version = 2
        cert.subject = ca
        cert.issuer = ca
        cert.serial = Time.now.to_i
        cert.public_key = key.public_key
        cert.not_before = Time.now - (24 * 60 * 60)
        cert.not_after = Time.now + (365 * 24 * 60 * 60)

        factory = OpenSSL::X509::ExtensionFactory.new
        factory.subject_certificate = cert
        factory.issuer_certificate = cert
        cert.extensions = [
          %w[basicConstraints CA:TRUE],
          %w[subjectKeyIdentifier hash],
          %w[subjectAltName] << [domain, hostname].map {|n| "DNS:#{n}" }.join(',')
        ].map {|k, v| factory.create_ext(k, v) }

        cert.sign(key, OpenSSL::Digest::SHA1.new)

        {'key' => key, 'crt' => cert}.each_pair do |ext, o| 
          name = File.join(dir, "#{domain}.#{ext}")
          File.open(name, "w") {|f| f.write(o.to_pem) }
        end
      end

      private

      def hostname
        Socket.gethostbyname(Socket.gethostname).first.downcase
      end
    end
  end
end
