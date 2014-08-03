# encoding: UTF-8

module Vines
  # An X509 certificate store that validates certificate trust chains.
  # This uses the conf/certs/*.crt files as the list of trusted root
  # CA certificates.
  class Store
    @@sources = nil

    # Create a certificate store to read certificate files from the given
    # directory.
    #
    # dir - The String directory name (absolute or relative).
    def initialize(dir)
      @dir = File.expand_path(dir)
      @store = OpenSSL::X509::Store.new
      certs.each {|c| @store.add_cert(c) }
    end

    # Return true if the certificate is signed by a CA certificate in the
    # store. If the certificate can be trusted, it's added to the store so
    # it can be used to trust other certs.
    #
    # pem - The PEM encoded certificate String.
    #
    # Returns true if the certificate is trusted.
    def trusted?(pem)
      if cert = OpenSSL::X509::Certificate.new(pem) rescue nil
        @store.verify(cert).tap do |trusted|
          @store.add_cert(cert) if trusted rescue nil
        end
      end
    end

    # Return true if the domain name matches one of the names in the
    # certificate. In other words, is the certificate provided to us really
    # for the domain to which we think we're connected?
    #
    # pem    - The PEM encoded certificate String.
    # domain - The domain name String.
    #
    # Returns true if the certificate was issued for the domain.
    def domain?(pem, domain)
      if cert = OpenSSL::X509::Certificate.new(pem) rescue nil
        OpenSSL::SSL.verify_certificate_identity(cert, domain) rescue false
      end
    end

    # Return the trusted root CA certificates installed in conf/certs. These
    # certificates are used to start the trust chain needed to validate certs
    # we receive from clients and servers.
    #
    # Returns an Array of OpenSSL::X509::Certificate objects.
    def certs
      @@sources ||= begin
        pattern = /-{5}BEGIN CERTIFICATE-{5}\n.*?-{5}END CERTIFICATE-{5}\n/m
        pairs = Dir[File.join(@dir, '*.crt')].map do |name|
          File.open(name, "r:UTF-8") do |f|
            pems = f.read.scan(pattern)
            certs = pems.map {|pem| OpenSSL::X509::Certificate.new(pem) }
            certs.reject! {|cert| cert.not_after < Time.now }
            [name, certs]
          end
        end
        Hash[pairs]
      end
      @@sources.values.flatten
    end

    # Returns a pair of file names containing the public key certificate
    # and matching private key for the given domain. This supports using
    # wildcard certificate files to serve several subdomains.
    #
    # Finding the certificate and private key file for a domain follows these steps:
    #
    # - Look for <domain>.crt and <domain>.key files in the conf/certs
    #   directory. If found, return those file names, otherwise . . .
    #
    # - Inspect all conf/certs/*.crt files for certificates that contain the
    #   domain name either as the subject common name (CN) or as a DNS
    #   subjectAltName. The corresponding private key must be in a file of the
    #   same name as the certificate's, but with a .key extension.
    #
    # So in the simplest configuration, the tea.wonderland.lit encryption files
    # would be named:
    #
    # - conf/certs/tea.wonderland.lit.crt
    # - conf/certs/tea.wonderland.lit.key
    #
    # However, in the case of a wildcard certificate for *.wonderland.lit,
    # the files would be:
    #
    # - conf/certs/wonderland.lit.crt
    # - conf/certs/wonderland.lit.key
    #
    # These same two files would be returned for the subdomains of:
    #
    # - tea.wonderland.lit
    # - crumpets.wonderland.lit
    # - etc.
    #
    # domain - The String domain name.
    #
    # Returns a two element String array for the certificate and private key
    #   file names or nil if not found.
    def files_for_domain(domain)
      crt = File.expand_path("#{domain}.crt", @dir)
      key = File.expand_path("#{domain}.key", @dir)
      return [crt, key] if File.exists?(crt) && File.exists?(key)

      # Might be a wildcard cert file.
      @@sources.each do |file, certs|
        certs.each do |cert|
          if OpenSSL::SSL.verify_certificate_identity(cert, domain)
            key = file.chomp(File.extname(file)) + '.key'
            return [file, key] if File.exists?(file) && File.exists?(key)
          end
        end
      end
      nil
    end
  end
end
