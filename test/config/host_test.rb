# encoding: UTF-8

require 'vines'
require 'minitest/autorun'

class HostTest < MiniTest::Unit::TestCase
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

  def test_duplicate_component_raises
    assert_raises(RuntimeError) do
      Vines::Config.new do
        host 'wonderland.lit' do
          storage(:fs) { dir '.' }
          components 'tea' => 'one'
          components 'TEA' => 'two'
        end
      end
    end
  end

  def test_duplicate_component_in_one_call_raises
    assert_raises(RuntimeError) do
      Vines::Config.new do
        host 'wonderland.lit' do
          storage(:fs) { dir '.' }
          components 'tea' => 'one', 'TEA' => 'two'
        end
      end
    end
  end

  def test_duplicate_component_symbol_raises
    assert_raises(RuntimeError) do
      Vines::Config.new do
        host 'wonderland.lit' do
          storage(:fs) { dir '.' }
          components 'tea' => 'one'
          components :TEA => 'two'
        end
      end
    end
  end

  def test_case_insensitive_component_name
    config = Vines::Config.new do
      host 'WONDERLAND.LIT' do
        storage(:fs) { dir '.' }
        components 'TEA' => 'secr3t', CAKE: 'Passw0rd'
      end
    end
    host = config.vhosts['wonderland.lit']
    refute_nil host
    assert_equal 2, host.components.size
    assert_equal host.components['tea.wonderland.lit'], 'secr3t'
    assert_equal host.components['cake.wonderland.lit'], 'Passw0rd'
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

  def test_default_private_storage_is_off
    config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir '.' }
      end
    end
    host = config.vhosts['wonderland.lit']
    refute_nil host
    refute host.private_storage?
  end

  def test_enable_private_storage
    config = Vines::Config.new do
      host 'wonderland.lit' do
        private_storage true
        storage(:fs) { dir '.' }
      end
    end
    host = config.vhosts['wonderland.lit']
    refute_nil host
    assert host.private_storage?
    assert config.private_storage?('wonderland.lit')
  end
end
