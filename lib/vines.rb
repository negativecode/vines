# encoding: UTF-8

module Vines
  NAMESPACES = {
    :stream           => 'http://etherx.jabber.org/streams'.freeze,
    :client           => 'jabber:client'.freeze,
    :server           => 'jabber:server'.freeze,
    :component        => 'jabber:component:accept'.freeze,
    :roster           => 'jabber:iq:roster'.freeze,
    :non_sasl         => 'jabber:iq:auth'.freeze,
    :storage          => 'jabber:iq:private'.freeze,
    :version          => 'jabber:iq:version'.freeze,
    :sasl             => 'urn:ietf:params:xml:ns:xmpp-sasl'.freeze,
    :tls              => 'urn:ietf:params:xml:ns:xmpp-tls'.freeze,
    :bind             => 'urn:ietf:params:xml:ns:xmpp-bind'.freeze,
    :session          => 'urn:ietf:params:xml:ns:xmpp-session'.freeze,
    :ping             => 'urn:xmpp:ping'.freeze,
    :pubsub           => 'http://jabber.org/protocol/pubsub'.freeze,
    :pubsub_event     => 'http://jabber.org/protocol/pubsub#event'.freeze,
    :pubsub_create    => 'http://jabber.org/protocol/pubsub#create-nodes'.freeze,
    :pubsub_delete    => 'http://jabber.org/protocol/pubsub#delete-nodes'.freeze,
    :pubsub_instant   => 'http://jabber.org/protocol/pubsub#instant-nodes'.freeze,
    :pubsub_item_ids  => 'http://jabber.org/protocol/pubsub#item-ids'.freeze,
    :pubsub_publish   => 'http://jabber.org/protocol/pubsub#publish'.freeze,
    :pubsub_subscribe => 'http://jabber.org/protocol/pubsub#subscribe'.freeze,
    :disco_items      => 'http://jabber.org/protocol/disco#items'.freeze,
    :disco_info       => 'http://jabber.org/protocol/disco#info'.freeze,
    :http_bind        => 'http://jabber.org/protocol/httpbind'.freeze,
    :bosh             => 'urn:xmpp:xbosh'.freeze,
    :vcard            => 'vcard-temp'.freeze,
    :si               => 'http://jabber.org/protocol/si'.freeze,
    :byte_streams     => 'http://jabber.org/protocol/bytestreams'.freeze
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
  digest/sha1
  eventmachine
  fiber
  fileutils
  logger
  nokogiri
  openssl
  resolv
  set
  socket
  uri
  yaml

  vines/log
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
  vines/stanza/iq/version
  vines/stanza/message
  vines/stanza/presence
  vines/stanza/presence/error
  vines/stanza/presence/probe
  vines/stanza/presence/subscribe
  vines/stanza/presence/subscribed
  vines/stanza/presence/unavailable
  vines/stanza/presence/unsubscribe
  vines/stanza/presence/unsubscribed
  vines/stanza/pubsub
  vines/stanza/pubsub/create
  vines/stanza/pubsub/delete
  vines/stanza/pubsub/publish
  vines/stanza/pubsub/subscribe
  vines/stanza/pubsub/unsubscribe

  vines/storage

  vines/config
  vines/config/host
  vines/config/port
  vines/config/pubsub

  vines/store
  vines/contact
  vines/daemon
  vines/error
  vines/kit
  vines/router
  vines/token_bucket
  vines/user
  vines/version
  vines/xmpp_server

  vines/cluster
  vines/cluster/connection
  vines/cluster/publisher
  vines/cluster/pubsub
  vines/cluster/sessions
  vines/cluster/subscriber

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
