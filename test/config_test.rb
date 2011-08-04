# encoding: UTF-8

require 'vines'
require 'minitest/autorun'

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
            dir '.'
          end
        end
        host 'wonderland.lit' do
          storage 'fs' do
            dir '.'
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
            dir '.'
          end
        end
      end
    end
  end

  def test_missing_storage
    assert_raises(RuntimeError) do
      Vines::Config.new do
        host 'wonderland.lit' do
          # missing storage
        end
      end
    end
  end

  def test_bad_storage
    assert_raises(RuntimeError) do
      Vines::Config.new do
        host 'wonderland.lit' do
          storage 'bogus' do
            # no bogus storage implementation
          end
        end
      end
    end
  end

  def test_duplicate_storage
    assert_raises(RuntimeError) do
      Vines::Config.new do
        host 'wonderland.lit' do
          storage('fs') { dir '.' }
          storage('fs') { dir '.' }
        end
      end
    end
  end

  def test_good_storage_raises_no_errors
    config = Vines::Config.new do
      host 'wonderland.lit' do
        storage 'fs' do
          dir '.'
        end
      end
    end
    refute_nil config.vhosts['wonderland.lit'].storage
  end

  def test_ldap_added_to_storage
    config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir '.' }
        # added after storage
        ldap 'ldap.wonderland.lit', 1636 do
          tls true
          dn 'cn=Directory Manager'
          password 'secr3t'
          basedn 'dc=wonderland,dc=lit'
          groupdn 'cn=chatters,dc=wonderland,dc=lit'
          object_class 'person'
          user_attr 'uid'
          name_attr 'cn'
        end
      end

      host 'verona.lit' do
        ldap 'ldap.verona.lit', 1636 do
          tls true
          dn 'cn=Directory Manager'
          password 'secr3t'
          basedn 'dc=wonderland,dc=lit'
          object_class 'person'
          user_attr 'uid'
          name_attr 'cn'
        end
        # added before storage
        storage(:fs) { dir '.' }
      end
    end
    %w[wonderland.lit verona.lit].each do |domain|
      refute_nil config.vhosts[domain].storage.ldap
      assert config.vhosts[domain].storage.ldap?
    end
  end

  def test_configure
    config = Vines::Config.configure do
      host 'wonderland.lit' do
        storage :fs do
          dir '.'
        end
      end
    end
    refute_nil config
    assert_same config, Vines::Config.instance
  end

  def test_vhost
    config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir '.' }
      end
    end
    assert_equal ['wonderland.lit'], config.vhosts.keys
    assert config.vhost?('wonderland.lit')
    refute config.vhost?('tea.wonderland.lit')
    refute config.vhost?('bogus')
  end

  def test_empty_component_name_raises
    assert_raises(RuntimeError) do
      Vines::Config.new do
        host 'wonderland.lit' do
          storage(:fs) { dir '.' }
          components '' => 'secr3t'
        end
      end
    end
  end

  def test_nil_component_name_raises
    assert_raises(RuntimeError) do
      Vines::Config.new do
        host 'wonderland.lit' do
          storage(:fs) { dir '.' }
          components nil => 'secr3t'
        end
      end
    end
  end

  def test_empty_component_password_raises
    assert_raises(RuntimeError) do
      Vines::Config.new do
        host 'wonderland.lit' do
          storage(:fs) { dir '.' }
          components 'tea' => ''
        end
      end
    end
  end

  def test_nil_component_password_raises
    assert_raises(RuntimeError) do
      Vines::Config.new do
        host 'wonderland.lit' do
          storage(:fs) { dir '.' }
          components 'tea' => nil
        end
      end
    end
  end

  def test_component?
    config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir '.' }
        components 'tea' => 'secr3t', cake: 'passw0rd'
      end
    end
    host = config.vhosts['wonderland.lit']
    refute_nil host
    refute host.component?(nil)
    refute host.component?('tea')
    refute host.component?(:cake)
    assert host.component?('tea.wonderland.lit')
    assert host.component?('cake.wonderland.lit')
    assert_nil host.password(nil)
    assert_nil host.password('bogus')
    assert_equal 'secr3t', host.password('tea.wonderland.lit')
    assert_equal 'passw0rd', host.password('cake.wonderland.lit')
    expected = {'tea.wonderland.lit' => 'secr3t', 'cake.wonderland.lit' => 'passw0rd'}
    assert_equal expected, host.components

    refute config.component?(nil)
    refute config.component?('tea')
    refute config.component?('bogus')
    assert config.component?('tea.wonderland.lit')
    assert config.component?('cake.wonderland.lit')
    assert config.component?('tea.wonderland.lit', 'cake.wonderland.lit')
    refute config.component?('tea.wonderland.lit', 'bogus.wonderland.lit')

    assert_nil config.component_password(nil)
    assert_nil config.component_password('bogus')
    assert_equal 'secr3t', config.component_password('tea.wonderland.lit')
    assert_equal 'passw0rd', config.component_password('cake.wonderland.lit')
  end

  def test_port_lookup
    config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir '.' }
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
        client
        client
      end
    end
  end

  def test_duplicate_server
    assert_raises(RuntimeError) do
      Vines::Config.new do
        server
        server
      end
    end
  end

  def test_duplicate_http
    assert_raises(RuntimeError) do
      Vines::Config.new do
        http
        http
      end
    end
  end

  def test_duplicate_component
    assert_raises(RuntimeError) do
      Vines::Config.new do
        component
        component
      end
    end
  end

  def test_default_client
    config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir '.' }
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
    refute port.private_storage?
    assert_equal Vines::Stream::Client, port.stream
    assert_same config, port.config
    assert_equal 1, config.ports.size
  end

  def test_configured_client
    config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir '.' }
      end
      client '0.0.0.1', 42 do
        private_storage true
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
    assert port.private_storage?
    assert_equal Vines::Stream::Client, port.stream
    assert_same config, port.config
    assert_equal 1, config.ports.size
  end

  def test_max_stanza_size
    config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir '.' }
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
        storage(:fs) { dir '.' }
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
        storage(:fs) { dir '.' }
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
    assert !config.s2s?('bogus')
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
        storage(:fs) { dir '.' }
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
    refute port.private_storage?
    assert_equal Vines::Stream::Http, port.stream
    assert_same config, port.config
    assert_equal 1, config.ports.size
  end

  def test_configured_http
    config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir '.' }
      end
      http '0.0.0.1', 42 do
        bind '/custom'
        private_storage true
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
    assert port.private_storage?
    assert_equal Vines::Stream::Http, port.stream
    assert_same config, port.config
    assert_equal 1, config.ports.size
  end

  def test_default_component
    config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir '.' }
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
        storage(:fs) { dir '.' }
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
          storage(:fs) { dir '.' }
        end
      end
    end
  end

  def test_valid_log_level
    config = Vines::Config.new do
      log :error
      host 'wonderland.lit' do
        storage(:fs) { dir '.' }
      end
    end
    assert_equal Logger::ERROR, Class.new.extend(Vines::Log).log.level
  end

  def test_cross_domain_messages
    config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir '.' }
      end
      host 'verona.lit' do
        cross_domain_messages true
        storage(:fs) { dir '.' }
      end
    end
    refute config.vhosts['wonderland.lit'].cross_domain_messages?
    assert config.vhosts['verona.lit'].cross_domain_messages?
  end

  def test_local_jid?
    config = Vines::Config.new do
      host 'wonderland.lit', 'verona.lit' do
        storage(:fs) { dir '.' }
      end
    end
    refute config.local_jid?(nil)
    refute config.local_jid?('alice@wonderland.lit', nil)
    assert config.local_jid?('alice@wonderland.lit')
    assert config.local_jid?('alice@wonderland.lit', 'romeo@verona.lit')
    refute config.local_jid?('alice@wonderland.lit', 'romeo@bogus.lit')
    refute config.local_jid?('alice@tea.wonderland.lit')
    refute config.local_jid?('alice@bogus.lit')
  end

  def test_missing_addresses_not_allowed
    config = Vines::Config.new do
      host 'wonderland.lit', 'verona.lit' do
        storage(:fs) { dir '.' }
      end
    end
    refute config.allowed?(nil, nil)
    refute config.allowed?('', '')
  end

  def test_same_domain_allowed
    config = Vines::Config.new do
      host 'wonderland.lit', 'verona.lit' do
        storage(:fs) { dir '.' }
      end
    end
    alice = Vines::JID.new('alice@wonderland.lit')
    hatter = Vines::JID.new('hatter@wonderland.lit')
    assert config.allowed?(alice, hatter)
  end

  def test_both_vhosts_with_cross_domain_allowed
    config = Vines::Config.new do
      host 'wonderland.lit', 'verona.lit' do
        cross_domain_messages true
        storage(:fs) { dir '.' }
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
        storage(:fs) { dir '.' }
      end
      host 'verona.lit' do
        cross_domain_messages false
        storage(:fs) { dir '.' }
      end
    end
    alice = Vines::JID.new('alice@wonderland.lit')
    romeo = Vines::JID.new('romeo@verona.lit')
    refute config.allowed?(alice, romeo)
    refute config.allowed?(romeo, alice)
  end

  def test_same_domain_component_to_component_allowed
    config = Vines::Config.new do
      host 'wonderland.lit' do
        cross_domain_messages false
        storage(:fs) { dir '.' }
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
        storage(:fs) { dir '.' }
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
        storage(:fs) { dir '.' }
        components 'tea' => 'secr3t', cake: 'passw0rd'
      end
    end
    config = Vines::Config.new do
      host 'verona.lit' do
        cross_domain_messages false
        storage(:fs) { dir '.' }
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
        storage(:fs) { dir '.' }
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
        storage(:fs) { dir '.' }
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
        storage(:fs) { dir '.' }
        components 'tea' => 'secr3t', cake: 'passw0rd'
      end
    end
    config = Vines::Config.new do
      host 'verona.lit' do
        cross_domain_messages false
        storage(:fs) { dir '.' }
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
        storage(:fs) { dir '.' }
        components 'tea' => 'secr3t', cake: 'passw0rd'
      end
      host 'verona.lit' do
        cross_domain_messages false
        storage(:fs) { dir '.' }
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

  def test_remote_user_to_local_user_allowed
    config = Vines::Config.new do
      host 'wonderland.lit' do
        cross_domain_messages true
        storage(:fs) { dir '.' }
      end
      host 'verona.lit' do
        cross_domain_messages false
        storage(:fs) { dir '.' }
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
        storage(:fs) { dir '.' }
      end
    end
    romeo = Vines::JID.new('romeo@verona.lit')
    hamlet = Vines::JID.new('hamlet@denmark.lit')
    refute config.allowed?(romeo, hamlet)
    refute config.allowed?(hamlet, romeo)
  end
end
