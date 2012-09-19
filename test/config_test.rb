# encoding: UTF-8

require 'test_helper'

class ConfigTest < MiniTest::Unit::TestCase
  def test_missing_host
    assert_raises(RuntimeError) do
      Vines::Config.new do
        # missing hosts
      end
    end
  end

  def test_duplicate_host
    assert_raises(RuntimeError) do
      Vines::Config.new do
        host 'wonderland.lit' do
          storage 'fs' do
            dir Dir.tmpdir
          end
        end
        host 'WONDERLAND.LIT' do
          storage 'fs' do
            dir Dir.tmpdir
          end
        end
      end
    end
  end

  def test_duplicate_host_in_one_call
    assert_raises(RuntimeError) do
      Vines::Config.new do
        host 'wonderland.lit', 'wonderland.lit' do
          storage 'fs' do
            dir Dir.tmpdir
          end
        end
      end
    end
  end

  def test_configure
    config = Vines::Config.configure do
      host 'wonderland.lit' do
        storage :fs do
          dir Dir.tmpdir
        end
      end
    end
    refute_nil config
    assert_same config, Vines::Config.instance
  end

  def test_vhost
    config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
      end
    end
    refute_nil config.vhost('wonderland.lit')
    refute_nil config.vhost(Vines::JID.new('wonderland.lit'))
    assert config.vhost?('wonderland.lit')
    assert config.vhost?(Vines::JID.new('wonderland.lit'))
    refute config.vhost?('alice@wonderland.lit')
    refute config.vhost?('tea.wonderland.lit')
    refute config.vhost?('bogus')
  end

  def test_port_lookup
    config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
      end
      client
    end
    refute_nil config[:client]
    assert_raises(ArgumentError) { config[:server] }
    assert_raises(ArgumentError) { config[:bogus] }
  end

  def test_duplicate_client
    assert_raises(RuntimeError) do
      Vines::Config.new do
        host 'wonderland.lit' do
          storage(:fs) { dir Dir.tmpdir }
        end
        client
        client
      end
    end
  end

  def test_duplicate_server
    assert_raises(RuntimeError) do
      Vines::Config.new do
        host 'wonderland.lit' do
          storage(:fs) { dir Dir.tmpdir }
        end
        server
        server
      end
    end
  end

  def test_duplicate_http
    assert_raises(RuntimeError) do
      Vines::Config.new do
        host 'wonderland.lit' do
          storage(:fs) { dir Dir.tmpdir }
        end
        http
        http
      end
    end
  end

  def test_duplicate_component
    assert_raises(RuntimeError) do
      Vines::Config.new do
        host 'wonderland.lit' do
          storage(:fs) { dir Dir.tmpdir }
        end
        component
        component
      end
    end
  end

  def test_duplicate_cluster
    assert_raises(RuntimeError) do
      Vines::Config.new do
        host 'wonderland.lit' do
          storage(:fs) { dir Dir.tmpdir }
        end
        cluster {}
        cluster {}
      end
    end
  end

  def test_missing_cluster
    config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
      end
    end
    assert_nil config.cluster
    refute config.cluster?
  end

  def test_cluster
    config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
      end
      cluster do
        host 'redis.wonderland.lit'
        port 12345
        database 8
        password 'secr3t'
      end
    end
    refute_nil config.cluster
    assert config.cluster?
    assert_equal 'redis.wonderland.lit', config.cluster.host
    assert_equal 12345, config.cluster.port
    assert_equal 8, config.cluster.database
    assert_equal 'secr3t', config.cluster.password
  end

  def test_default_client
    config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
      end
      client
    end
    port = config.ports.first
    refute_nil port
    assert_equal Vines::Config::ClientPort, port.class
    assert_equal '0.0.0.0', port.host
    assert_equal 5222, port.port
    assert_equal 131_072, port.max_stanza_size
    assert_equal 5, port.max_resources_per_account
    assert_equal Vines::Stream::Client, port.stream
    assert_same config, port.config
    assert_equal 1, config.ports.size
  end

  def test_configured_client
    config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
      end
      client '0.0.0.1', 42 do
        max_stanza_size 60_000
        max_resources_per_account 1
      end
    end
    port = config.ports.first
    refute_nil port
    assert_equal Vines::Config::ClientPort, port.class
    assert_equal '0.0.0.1', port.host
    assert_equal 42, port.port
    assert_equal 60_000, port.max_stanza_size
    assert_equal 1, port.max_resources_per_account
    assert_equal Vines::Stream::Client, port.stream
    assert_same config, port.config
    assert_equal 1, config.ports.size
  end

  def test_max_stanza_size
    config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
      end
      client do
        max_stanza_size 0
      end
    end
    assert_equal 10_000, config.ports.first.max_stanza_size
  end

  def test_default_server
    config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
      end
      server
    end
    port = config.ports.first
    refute_nil port
    assert !config.s2s?('verona.lit')
    assert_equal Vines::Config::ServerPort, port.class
    assert_equal '0.0.0.0', port.host
    assert_equal 5269, port.port
    assert_equal 131_072, port.max_stanza_size
    assert_equal Vines::Stream::Server, port.stream
    assert_same config, port.config
    assert_equal 1, config.ports.size
  end

  def test_configured_server
    config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
      end
      server '0.0.0.1', 42 do
        max_stanza_size 60_000
        hosts ['verona.lit', 'denmark.lit']
      end
    end
    port = config.ports.first
    refute_nil port
    assert config.s2s?('verona.lit')
    assert config.s2s?('denmark.lit')
    assert config.s2s?(Vines::JID.new('denmark.lit'))
    refute config.s2s?(Vines::JID.new('hamlet@denmark.lit'))
    refute config.s2s?('bogus')
    refute config.s2s?(nil)
    assert_equal Vines::Config::ServerPort, port.class
    assert_equal '0.0.0.1', port.host
    assert_equal 42, port.port
    assert_equal 60_000, port.max_stanza_size
    assert_equal Vines::Stream::Server, port.stream
    assert_same config, port.config
    assert_equal 1, config.ports.size
  end

  def test_default_http
    config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
      end
      http
    end
    port = config.ports.first
    refute_nil port
    assert_equal Vines::Config::HttpPort, port.class
    assert_equal '0.0.0.0', port.host
    assert_equal 5280, port.port
    assert_equal 131_072, port.max_stanza_size
    assert_equal 5, port.max_resources_per_account
    assert_equal File.join(Dir.pwd, 'web'), port.root
    assert_equal '/xmpp', port.bind
    assert_equal Vines::Stream::Http, port.stream
    assert_same config, port.config
    assert_equal 1, config.ports.size
  end

  def test_configured_http
    config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
      end
      http '0.0.0.1', 42 do
        bind '/custom'
        max_stanza_size 60_000
        max_resources_per_account 1
        root '/var/www/html'
      end
    end
    port = config.ports.first
    refute_nil port
    assert_equal Vines::Config::HttpPort, port.class
    assert_equal '0.0.0.1', port.host
    assert_equal 42, port.port
    assert_equal 60_000, port.max_stanza_size
    assert_equal 1, port.max_resources_per_account
    assert_equal '/var/www/html', port.root
    assert_equal '/custom', port.bind
    assert_equal Vines::Stream::Http, port.stream
    assert_same config, port.config
    assert_equal 1, config.ports.size
  end

  def test_default_component
    config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
      end
      component
    end
    port = config.ports.first
    refute_nil port
    assert_equal Vines::Config::ComponentPort, port.class
    assert_equal '0.0.0.0', port.host
    assert_equal 5347, port.port
    assert_equal 131_072, port.max_stanza_size
    assert_equal Vines::Stream::Component, port.stream
    assert_same config, port.config
    assert_equal 1, config.ports.size
  end

  def test_configured_component
    config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
      end
      component '0.0.0.1', 42 do
        max_stanza_size 60_000
      end
    end
    port = config.ports.first
    refute_nil port
    assert_equal Vines::Config::ComponentPort, port.class
    assert_equal '0.0.0.1', port.host
    assert_equal 42, port.port
    assert_equal 60_000, port.max_stanza_size
    assert_equal Vines::Stream::Component, port.stream
    assert_same config, port.config
    assert_equal 1, config.ports.size
  end

  def test_invalid_log_level
    assert_raises(RuntimeError) do
      config = Vines::Config.new do
        log 'bogus'
        host 'wonderland.lit' do
          storage(:fs) { dir Dir.tmpdir }
        end
      end
    end
  end

  def test_valid_log_level
    config = Vines::Config.new do
      log :error
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
      end
    end
    assert_equal Logger::ERROR, Class.new.extend(Vines::Log).log.level
  end

  def test_null_storage
    config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
      end
    end
    assert_equal Vines::Storage::Local, config.storage('wonderland.lit').class
    assert_equal Vines::Storage::Null, config.storage('bogus').class
  end

  def test_cross_domain_messages
    config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
      end
      host 'verona.lit' do
        cross_domain_messages true
        storage(:fs) { dir Dir.tmpdir }
      end
    end
    refute config.vhost('wonderland.lit').cross_domain_messages?
    assert config.vhost('verona.lit').cross_domain_messages?
  end

  def test_local_jid?
    config = Vines::Config.new do
      host 'wonderland.lit', 'verona.lit' do
        storage(:fs) { dir Dir.tmpdir }
      end
    end
    refute config.local_jid?(nil)
    refute config.local_jid?('alice@wonderland.lit', nil)
    assert config.local_jid?('alice@wonderland.lit')
    assert config.local_jid?(Vines::JID.new('alice@wonderland.lit'))
    assert config.local_jid?(Vines::JID.new('wonderland.lit'))
    assert config.local_jid?('alice@wonderland.lit', 'romeo@verona.lit')
    refute config.local_jid?('alice@wonderland.lit', 'romeo@bogus.lit')
    refute config.local_jid?('alice@tea.wonderland.lit')
    refute config.local_jid?('alice@bogus.lit')
  end

  def test_missing_addresses_not_allowed
    config = Vines::Config.new do
      host 'wonderland.lit', 'verona.lit' do
        storage(:fs) { dir Dir.tmpdir }
      end
    end
    refute config.allowed?(nil, nil)
    refute config.allowed?('', '')
  end

  def test_same_domain_allowed
    config = Vines::Config.new do
      host 'wonderland.lit', 'verona.lit' do
        storage(:fs) { dir Dir.tmpdir }
      end
    end
    alice = Vines::JID.new('alice@wonderland.lit')
    hatter = Vines::JID.new('hatter@wonderland.lit')
    assert config.allowed?(alice, hatter)
    assert config.allowed?(hatter, alice)
    assert config.allowed?('wonderland.lit', alice)
  end

  def test_both_vhosts_with_cross_domain_allowed
    config = Vines::Config.new do
      host 'wonderland.lit', 'verona.lit' do
        cross_domain_messages true
        storage(:fs) { dir Dir.tmpdir }
      end
    end
    alice = Vines::JID.new('alice@wonderland.lit')
    romeo = Vines::JID.new('romeo@verona.lit')
    assert config.allowed?(alice, romeo)
    assert config.allowed?(romeo, alice)
  end

  def test_one_vhost_with_cross_domain_not_allowed
    config = Vines::Config.new do
      host 'wonderland.lit' do
        cross_domain_messages true
        storage(:fs) { dir Dir.tmpdir }
      end
      host 'verona.lit' do
        cross_domain_messages false
        storage(:fs) { dir Dir.tmpdir }
      end
    end
    alice = Vines::JID.new('alice@wonderland.lit')
    romeo = Vines::JID.new('romeo@verona.lit')
    refute config.allowed?(alice, romeo)
    refute config.allowed?(romeo, alice)
  end

  def test_same_domain_component_to_pubsub_allowed
    config = Vines::Config.new do
      host 'wonderland.lit' do
        cross_domain_messages false
        storage(:fs) { dir Dir.tmpdir }
        components 'tea' => 'secr3t', cake: 'passw0rd'
        pubsub 'games'
      end
    end
    alice = Vines::JID.new('alice@tea.wonderland.lit')
    tea = Vines::JID.new('tea.wonderland.lit')
    pubsub = Vines::JID.new('games.wonderland.lit')
    assert config.allowed?(alice, pubsub)
    assert config.allowed?(pubsub, alice)
    assert config.allowed?(tea, pubsub)
    assert config.allowed?(pubsub, tea)
  end

  def test_cross_domain_component_to_pubsub_allowed
    config = Vines::Config.new do
      host 'wonderland.lit', 'verona.lit' do
        cross_domain_messages true
        storage(:fs) { dir Dir.tmpdir }
        components 'tea' => 'secr3t', cake: 'passw0rd'
        pubsub 'games'
      end
    end
    alice = Vines::JID.new('alice@tea.wonderland.lit')
    tea = Vines::JID.new('tea.wonderland.lit')
    pubsub = Vines::JID.new('games.verona.lit')
    assert config.allowed?(alice, pubsub)
    assert config.allowed?(pubsub, alice)
    assert config.allowed?(tea, pubsub)
    assert config.allowed?(pubsub, tea)
  end

  def test_cross_domain_component_to_pubsub_not_allowed
    config = Vines::Config.new do
      host 'wonderland.lit' do
        cross_domain_messages true
        storage(:fs) { dir Dir.tmpdir }
        components 'tea' => 'secr3t', cake: 'passw0rd'
        pubsub 'games'
      end
      host 'verona.lit' do
        cross_domain_messages false
        storage(:fs) { dir Dir.tmpdir }
        components 'party' => 'secr3t'
      end
    end
    romeo = Vines::JID.new('romeo@party.verona.lit')
    party = Vines::JID.new('party.verona.lit')
    pubsub = Vines::JID.new('games.wonderland.lit')
    refute config.allowed?(romeo, pubsub)
    refute config.allowed?(pubsub, romeo)
    refute config.allowed?(party, pubsub)
    refute config.allowed?(pubsub, party)
  end

  def test_same_domain_component_to_component_allowed
    config = Vines::Config.new do
      host 'wonderland.lit' do
        cross_domain_messages false
        storage(:fs) { dir Dir.tmpdir }
        components 'tea' => 'secr3t', cake: 'passw0rd'
      end
    end
    alice = Vines::JID.new('alice@tea.wonderland.lit')
    hatter = Vines::JID.new('hatter@cake.wonderland.lit')
    assert config.allowed?(alice, alice)
    assert config.allowed?(alice, hatter)
    assert config.allowed?(hatter, alice)
  end

  def test_cross_domain_component_to_component_allowed
    config = Vines::Config.new do
      host 'wonderland.lit', 'verona.lit' do
        cross_domain_messages true
        storage(:fs) { dir Dir.tmpdir }
        components 'tea' => 'secr3t', cake: 'passw0rd'
      end
    end
    alice = Vines::JID.new('alice@tea.wonderland.lit')
    romeo = Vines::JID.new('romeo@cake.verona.lit')
    assert config.allowed?(alice, romeo)
    assert config.allowed?(romeo, alice)
  end

  def test_cross_domain_component_to_component_not_allowed
    config = Vines::Config.new do
      host 'wonderland.lit' do
        cross_domain_messages true
        storage(:fs) { dir Dir.tmpdir }
        components 'tea' => 'secr3t', cake: 'passw0rd'
      end
      host 'verona.lit' do
        cross_domain_messages false
        storage(:fs) { dir Dir.tmpdir }
        components 'party' => 'secr3t'
      end
    end
    alice = Vines::JID.new('alice@tea.wonderland.lit')
    romeo = Vines::JID.new('romeo@party.verona.lit')
    refute config.allowed?(alice, romeo)
    refute config.allowed?(romeo, alice)
  end

  def test_same_domain_user_to_component_allowed
    config = Vines::Config.new do
      host 'wonderland.lit' do
        cross_domain_messages false
        storage(:fs) { dir Dir.tmpdir }
        components 'tea' => 'secr3t', cake: 'passw0rd'
      end
    end
    alice = Vines::JID.new('alice@wonderland.lit')
    comp = Vines::JID.new('hatter@cake.wonderland.lit')
    assert config.allowed?(alice, comp)
    assert config.allowed?(comp, alice)
  end

  def test_cross_domain_user_to_component_allowed
    config = Vines::Config.new do
      host 'wonderland.lit', 'verona.lit' do
        cross_domain_messages true
        storage(:fs) { dir Dir.tmpdir }
        components 'tea' => 'secr3t', cake: 'passw0rd'
      end
    end
    alice = Vines::JID.new('alice@tea.wonderland.lit')
    romeo = Vines::JID.new('romeo@verona.lit')
    assert config.allowed?(alice, romeo)
    assert config.allowed?(romeo, alice)
  end

  def test_cross_domain_user_to_component_not_allowed
    config = Vines::Config.new do
      host 'wonderland.lit' do
        cross_domain_messages true
        storage(:fs) { dir Dir.tmpdir }
        components 'tea' => 'secr3t', cake: 'passw0rd'
      end
      host 'verona.lit' do
        cross_domain_messages false
        storage(:fs) { dir Dir.tmpdir }
      end
    end
    alice = Vines::JID.new('alice@tea.wonderland.lit')
    romeo = Vines::JID.new('romeo@verona.lit')
    refute config.allowed?(alice, romeo)
    refute config.allowed?(romeo, alice)
  end

  def test_remote_user_to_component_allowed
    config = Vines::Config.new do
      host 'wonderland.lit' do
        cross_domain_messages true
        storage(:fs) { dir Dir.tmpdir }
        components 'tea' => 'secr3t', cake: 'passw0rd'
      end
      host 'verona.lit' do
        cross_domain_messages false
        storage(:fs) { dir Dir.tmpdir }
        components 'tea' => 'secr3t', cake: 'passw0rd'
      end
    end
    alice = Vines::JID.new('alice@tea.wonderland.lit')
    romeo = Vines::JID.new('romeo@tea.verona.lit')
    hamlet = Vines::JID.new('hamlet@denmark.lit')
    assert config.allowed?(alice, hamlet)
    assert config.allowed?(hamlet, alice)
    refute config.allowed?(romeo, hamlet)
    refute config.allowed?(hamlet, romeo)
  end

  def test_same_domain_user_to_pubsub_allowed
    config = Vines::Config.new do
      host 'wonderland.lit' do
        cross_domain_messages false
        storage(:fs) { dir Dir.tmpdir }
        pubsub 'games'
      end
    end
    alice = Vines::JID.new('alice@wonderland.lit')
    pubsub = Vines::JID.new('games.wonderland.lit')
    assert config.allowed?(alice, pubsub)
    assert config.allowed?(pubsub, alice)
  end

  def test_cross_domain_user_to_pubsub_not_allowed
    config = Vines::Config.new do
      host 'wonderland.lit' do
        cross_domain_messages true
        storage(:fs) { dir Dir.tmpdir }
        pubsub 'games'
      end
      host 'verona.lit' do
        cross_domain_messages false
        storage(:fs) { dir Dir.tmpdir }
      end
    end
    pubsub = Vines::JID.new('games.wonderland.lit')
    romeo = Vines::JID.new('romeo@verona.lit')
    refute config.allowed?(pubsub, romeo)
    refute config.allowed?(romeo, pubsub)
  end

  def test_remote_user_to_pubsub_allowed
    config = Vines::Config.new do
      host 'wonderland.lit' do
        cross_domain_messages true
        storage(:fs) { dir Dir.tmpdir }
        pubsub 'games'
      end
      host 'verona.lit' do
        cross_domain_messages false
        storage(:fs) { dir Dir.tmpdir }
        pubsub 'games'
      end
    end
    wonderland = Vines::JID.new('games.wonderland.lit')
    verona = Vines::JID.new('games.verona.lit')
    hamlet = Vines::JID.new('hamlet@denmark.lit')
    assert config.allowed?(wonderland, hamlet)
    assert config.allowed?(hamlet, wonderland)
    refute config.allowed?(verona, hamlet)
    refute config.allowed?(hamlet, verona)
  end

  def test_remote_user_to_local_user_allowed
    config = Vines::Config.new do
      host 'wonderland.lit' do
        cross_domain_messages true
        storage(:fs) { dir Dir.tmpdir }
      end
      host 'verona.lit' do
        cross_domain_messages false
        storage(:fs) { dir Dir.tmpdir }
      end
    end
    alice = Vines::JID.new('alice@wonderland.lit')
    romeo = Vines::JID.new('romeo@verona.lit')
    hamlet = Vines::JID.new('hamlet@denmark.lit')
    assert config.allowed?(alice, hamlet)
    assert config.allowed?(hamlet, alice)
    refute config.allowed?(romeo, hamlet)
    refute config.allowed?(hamlet, romeo)
  end

  def test_remote_user_to_remote_user_not_allowed
    config = Vines::Config.new do
      host 'wonderland.lit' do
        cross_domain_messages true
        storage(:fs) { dir Dir.tmpdir }
      end
    end
    romeo = Vines::JID.new('romeo@verona.lit')
    hamlet = Vines::JID.new('hamlet@denmark.lit')
    refute config.allowed?(romeo, hamlet)
    refute config.allowed?(hamlet, romeo)
  end
end
