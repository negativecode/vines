# encoding: UTF-8

require 'vines'
require 'minitest/autorun'

describe Vines::Storage::Ldap do
  ALICE_DN = 'uid=alice@wondlerand.lit,ou=People,dc=wonderland,dc=lit'
  CONTEXT = {}

  after do
    CONTEXT.clear
  end

  describe '#initialize' do
    it 'raises with missing host and port' do
      assert_raises(RuntimeError) do
        Vines::Storage::Ldap.new(nil, nil) do
          tls true
          dn 'cn=Directory Manager'
          password 'secr3t'
          basedn 'dc=wonderland,dc=lit'
          object_class 'person'
          user_attr 'uid'
          name_attr 'cn'
        end
      end
    end

    it 'does not raise when using default host and port' do
      Vines::Storage::Ldap.new do
        tls true
        dn 'cn=Directory Manager'
        password 'secr3t'
        basedn 'dc=wonderland,dc=lit'
        object_class 'person'
        user_attr 'uid'
        name_attr 'cn'
      end
    end

    it 'does not raise when given a host and port' do
      Vines::Storage::Ldap.new('0.0.0.1', 42) do
        tls true
        dn 'cn=Directory Manager'
        password 'secr3t'
        basedn 'dc=wonderland,dc=lit'
        object_class 'person'
        user_attr 'uid'
        name_attr 'cn'
      end
    end

    it 'raises when given no parameters' do
      assert_raises(RuntimeError) do
        Vines::Storage::Ldap.new {}
      end
    end

    it 'raises when given blank parameters' do
      assert_raises(RuntimeError) do
        Vines::Storage::Ldap.new do
          tls
          dn
          password
          basedn
          object_class
          user_attr
          name_attr
        end
      end
    end

    it 'handles boolean false values without raising' do
      Vines::Storage::Ldap.new do
        tls false
        dn 'cn=Directory Manager'
        password 'secr3t'
        basedn 'dc=wonderland,dc=lit'
        object_class 'person'
        user_attr 'uid'
        name_attr 'cn'
      end
    end
  end

  describe '#authenticate' do
    it 'fails with invalid credentials' do
      ldap = connect
      assert_nil ldap.authenticate(nil, nil)
      assert_nil ldap.authenticate('', '')
      assert_nil ldap.authenticate('alice@wonderland.lit', ' ')
      assert_nil ldap.authenticate('bogus"jid@wonderland.lit', 'password')
      assert_nil ldap.authenticate(Vines::JID.new('alice@wonderland.lit'), '')
    end

    it 'fails when user not found' do
      CONTEXT.merge!({
        :mock_ldap => MiniTest::Mock.new,
        :connect_calls => 0
      })
      ldap = connect
      def ldap.connect(dn, password)
        CONTEXT[:connect_calls] += 1
        raise unless 'cn=Directory Manager' == dn
        raise unless 'secr3t' == password

        clas = Net::LDAP::Filter.eq('objectClass', 'person')
        uid = Net::LDAP::Filter.eq('uid', 'alice@wonderland.lit')

        mock = CONTEXT[:mock_ldap]
        mock.expect(:search, [], [{:attributes => ['cn', 'mail'], :filter => clas & uid}])
      end
      assert_nil ldap.authenticate('alice@wonderland.lit', 'passw0rd')
      assert CONTEXT[:mock_ldap]
      assert_equal 1, CONTEXT[:connect_calls]
    end

    it 'fails when user cannot bind' do
      CONTEXT.merge!({
        :credentials => [
          {:dn => 'cn=Directory Manager', :password => 'secr3t'},
          {:dn => ALICE_DN, :password => 'passw0rd'}
        ],
        :mock_ldap => MiniTest::Mock.new,
        :mock_entry => MiniTest::Mock.new,
        :connect_calls => 0
      })
      ldap = connect
      def ldap.connect(dn, password)
        credentials = CONTEXT[:credentials][CONTEXT[:connect_calls]]
        CONTEXT[:connect_calls] += 1
        raise unless credentials[:dn] == dn && credentials[:password] == password

        clas = Net::LDAP::Filter.eq('objectClass', 'person')
        uid = Net::LDAP::Filter.eq('uid', 'alice@wonderland.lit')

        entry = CONTEXT[:mock_entry]
        entry.expect(:dn, ALICE_DN)

        mock = CONTEXT[:mock_ldap]
        mock.expect(:search, [entry], [{:attributes => ['cn', 'mail'], :filter => clas & uid}])
        mock.expect(:bind, false)
      end
      assert_nil ldap.authenticate('alice@wonderland.lit', 'passw0rd')
      assert_equal 2, CONTEXT[:connect_calls]
      assert CONTEXT[:mock_entry].verify
      assert CONTEXT[:mock_ldap].verify
    end

    it 'authenticates successfully with proper credentials' do
      CONTEXT.merge!({
        :credentials => [
          {:dn => 'cn=Directory Manager', :password => 'secr3t'},
          {:dn => ALICE_DN, :password => 'passw0rd'}
        ],
        :mock_ldap => MiniTest::Mock.new,
        :mock_entry => MiniTest::Mock.new,
        :connect_calls => 0
      })
      ldap = connect
      def ldap.connect(dn, password)
        credentials = CONTEXT[:credentials][CONTEXT[:connect_calls]]
        CONTEXT[:connect_calls] += 1
        raise unless credentials[:dn] == dn && credentials[:password] == password

        clas = Net::LDAP::Filter.eq('objectClass', 'person')
        uid = Net::LDAP::Filter.eq('uid', 'alice@wonderland.lit')

        entry = CONTEXT[:mock_entry]
        entry.expect(:dn, ALICE_DN)
        entry.expect(:[], ['Alice Liddell'], ['cn'])

        mock = CONTEXT[:mock_ldap]
        mock.expect(:search, [entry], [{:attributes => ['cn', 'mail'], :filter => clas & uid}])
        mock.expect(:bind, true)
      end
      user = ldap.authenticate('alice@wonderland.lit', 'passw0rd')
      refute_nil user
      assert_equal 'alice@wonderland.lit', user.jid.to_s
      assert_equal 'Alice Liddell', user.name
      assert_equal [], user.roster

      assert_equal 2, CONTEXT[:connect_calls]
      assert CONTEXT[:mock_entry].verify
      assert CONTEXT[:mock_ldap].verify
    end
  end

  private

  def connect
    Vines::Storage::Ldap.new('0.0.0.0', 636) do
      tls true
      dn 'cn=Directory Manager'
      password 'secr3t'
      basedn 'dc=wonderland,dc=lit'
      object_class 'person'
      user_attr 'uid'
      name_attr 'cn'
    end
  end
end
