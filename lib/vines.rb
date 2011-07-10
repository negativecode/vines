# encoding: UTF-8

module Vines
  NAMESPACES = {
    :stream       => 'http://etherx.jabber.org/streams'.freeze,
    :client       => 'jabber:client'.freeze,
    :server       => 'jabber:server'.freeze,
    :component    => 'jabber:component:accept'.freeze,
    :roster       => 'jabber:iq:roster'.freeze,
    :non_sasl     => 'jabber:iq:auth'.freeze,
    :storage      => 'jabber:iq:private'.freeze,
    :sasl         => 'urn:ietf:params:xml:ns:xmpp-sasl'.freeze,
    :tls          => 'urn:ietf:params:xml:ns:xmpp-tls'.freeze,
    :bind         => 'urn:ietf:params:xml:ns:xmpp-bind'.freeze,
    :session      => 'urn:ietf:params:xml:ns:xmpp-session'.freeze,
    :ping         => 'urn:xmpp:ping'.freeze,
    :disco_items  => 'http://jabber.org/protocol/disco#items'.freeze,
    :disco_info   => 'http://jabber.org/protocol/disco#info'.freeze,
    :http_bind    => 'http://jabber.org/protocol/httpbind'.freeze,
    :bosh         => 'urn:xmpp:xbosh'.freeze,
    :vcard        => 'vcard-temp'.freeze,
    :si           => 'http://jabber.org/protocol/si'.freeze,
    :byte_streams => 'http://jabber.org/protocol/bytestreams'.freeze
  }.freeze

  module Log
    @@logger = nil
    def log
      unless @@logger
        @@logger = Logger.new(STDOUT)
        @@logger.level = Logger::INFO
        @@logger.progname = 'vines'
        @@logger.formatter = Class.new(Logger::Formatter) do
          def initialize
            @time = "%Y-%m-%dT%H:%M:%SZ".freeze
            @fmt  = "[%s] %5s -- %s: %s\n".freeze
          end
          def call(severity, time, program, msg)
            @fmt % [time.utc.strftime(@time), severity, program, msg2str(msg)]
          end
        end.new
      end
      @@logger
    end
  end
end

%w[
  resolv-replace
  active_record
  base64
  bcrypt
  digest/sha1
  em-http
  em-redis
  eventmachine
  fiber
  fileutils
  http/parser
  logger
  net/ldap
  nokogiri
  openssl
  socket
  uri
  yaml

  vines/jid
  vines/stanza
  vines/stanza/iq
  vines/stanza/iq/query
  vines/stanza/iq/auth
  vines/stanza/iq/disco_info
  vines/stanza/iq/disco_items
  vines/stanza/iq/error
  vines/stanza/iq/ping
  vines/stanza/iq/private_storage
  vines/stanza/iq/result
  vines/stanza/iq/roster
  vines/stanza/iq/session
  vines/stanza/iq/vcard
  vines/stanza/message
  vines/stanza/presence
  vines/stanza/presence/error
  vines/stanza/presence/probe
  vines/stanza/presence/subscribe
  vines/stanza/presence/subscribed
  vines/stanza/presence/unavailable
  vines/stanza/presence/unsubscribe
  vines/stanza/presence/unsubscribed

  vines/storage
  vines/storage/couchdb
  vines/storage/ldap
  vines/storage/local
  vines/storage/redis
  vines/storage/sql

  vines/store
  vines/contact
  vines/config
  vines/daemon
  vines/error
  vines/kit
  vines/router
  vines/token_bucket
  vines/user
  vines/version
  vines/xmpp_server

  vines/stream
  vines/stream/state
  vines/stream/parser

  vines/stream/client
  vines/stream/client/session
  vines/stream/client/start
  vines/stream/client/tls
  vines/stream/client/auth_restart
  vines/stream/client/auth
  vines/stream/client/bind_restart
  vines/stream/client/bind
  vines/stream/client/ready
  vines/stream/client/closed

  vines/stream/component
  vines/stream/component/start
  vines/stream/component/handshake
  vines/stream/component/ready

  vines/stream/http
  vines/stream/http/session
  vines/stream/http/sessions
  vines/stream/http/request
  vines/stream/http/start
  vines/stream/http/auth
  vines/stream/http/bind_restart
  vines/stream/http/bind
  vines/stream/http/ready

  vines/stream/server
  vines/stream/server/start
  vines/stream/server/tls
  vines/stream/server/auth_restart
  vines/stream/server/auth
  vines/stream/server/final_restart
  vines/stream/server/ready

  vines/stream/server/outbound/start
  vines/stream/server/outbound/tls
  vines/stream/server/outbound/tls_result
  vines/stream/server/outbound/auth_restart
  vines/stream/server/outbound/auth
  vines/stream/server/outbound/auth_result
  vines/stream/server/outbound/final_restart
  vines/stream/server/outbound/final_features

  vines/command/bcrypt
  vines/command/cert
  vines/command/init
  vines/command/ldap
  vines/command/restart
  vines/command/schema
  vines/command/start
  vines/command/stop
].each {|f| require f }
