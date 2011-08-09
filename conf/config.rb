# encoding: UTF-8

# This is the Vines XMPP server configuration file. Restart the server with
# 'vines restart' after updating this file.

Vines::Config.configure do
  # Set the logging level to debug, info, warn, error, or fatal. The debug
  # level logs all XML sent and received by the server.
  log :info

  # Each host element below is a virtual host domain name that this server will
  # service. Hosts can share storage configurations or use separate databases.
  # TLS encryption is mandatory so each host must have a <domain>.crt and
  # <domain>.key file in the conf/certs directory. A self-signed certificate can
  # be generated for a virtual host domain with the 'vines cert <domain.tld>'
  # command. Change the example, 'wonderland.lit', domain name to your actual
  # domain.
  #
  # The private_storage attribute allows clients to store XML fragments
  # on the server, using the XEP-0049 Private XML Storage feature.
  #
  # Shared storage example:
  # host 'verona.lit', 'wonderland.lit' do
  #   private_storage false
  #   cross_domain_messages false
  #   storage 'fs' do
  #     dir 'data/users'
  #   end
  #   components 'tea'  => 'secr3t',
  #              'cake' => 'passw0rd'
  # end

  host 'wonderland.lit' do
    cross_domain_messages false
    private_storage false
    storage 'fs' do
      dir 'data/users'
    end
    # components 'tea'  => 'secr3t',
    #            'cake' => 'passw0rd'
  end

  # Hosts can use LDAP authentication that overrides the authentication
  # provided by a storage database. If LDAP is in use, passwords are not
  # saved or validated against the storage database. However, all other user
  # information, like rosters, is still saved in the storage database.
  #
  # host 'wonderland.lit' do
  #   cross_domain_messages false
  #   private_storage false
  #   storage 'fs' do
  #     dir 'data/users'
  #   end
  #   ldap 'ldap.wonderland.lit', 636 do
  #     dn 'cn=Directory Manager'
  #     password 'secr3t'
  #     basedn 'dc=wonderland,dc=lit'
  #     groupdn 'cn=chatters,dc=wonderland,dc=lit' # optional
  #     object_class 'person'
  #     user_attr 'uid'
  #     name_attr 'cn'
  #     tls true
  #   end
  #   components 'tea'  => 'secr3t',
  #              'cake' => 'passw0rd'
  # end

  # Configure the client-to-server port. The max_resources_per_account attribute
  # limits how many concurrent connections one user can have to the server.
  client '0.0.0.0', 5222 do
    max_stanza_size 65536
    max_resources_per_account 5
  end

  # Configure the server-to-server port. The max_stanza_size attribute should be
  # much larger than the setting for client-to-server. Add domain names to the
  # 'hosts' white-list attribute to allow those servers to connect. Any connection
  # attempt from a host not in this list will be denied.
  server '0.0.0.0', 5269 do
    max_stanza_size 131072
    hosts []
  end

  # Configure the built-in HTTP server that serves static files and responds to
  # XEP-0124 BOSH requests. This allows HTTP clients to connect to
  # the XMPP server. The root attribute defines the web server's document root.
  # It will only serve files out of this directory. The bind attribute defines
  # the URL to which BOSH clients must POST their XMPP stanza requests.
  http '0.0.0.0', 5280 do
    bind '/xmpp'
    max_stanza_size 65536
    max_resources_per_account 5
    root 'web'
  end

  # Configure the XEP-0114 external component port. Component sub-domains and
  # their passwords are defined with their virtual host entries above.
  component '0.0.0.0', 5347 do
    max_stanza_size 131072
  end
end

# Available storage implementations:

#storage 'fs' do
#  dir 'data/users'
#end

#storage 'couchdb' do
#  host 'localhost'
#  port 6984
#  database 'xmpp'
#  tls true
#  username ''
#  password ''
#end

#storage 'redis' do
#  host 'localhost'
#  port 6379
#  database 0
#  password ''
#end

#storage 'sql' do
#  adapter 'postgresql'
#  host 'localhost'
#  port 5432
#  database 'xmpp'
#  username ''
#  password ''
#  pool 5
#end
