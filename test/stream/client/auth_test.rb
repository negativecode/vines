# encoding: UTF-8

require 'vines'
require 'minitest/autorun'

class ClientAuthTest < MiniTest::Unit::TestCase
  # disable logging for tests
  Class.new.extend(Vines::Log).log.level = Logger::FATAL

  class MockStorage < Vines::Storage
    def initialize(raise_error=false)
      @raise_error = raise_error
    end

    def authenticate(username, password)
      raise 'temp auth fail' if @raise_error
      user = Vines::User.new(:jid => 'alice@wonderland.lit')
      users = {'alice@wonderland.lit' => 'secr3t'}
      (users.key?(username) && (users[username] == password)) ? user : nil
    end

    def find_user(jid)
    end

    def save_user(user)
    end
  end

  def setup
    @stream = MiniTest::Mock.new
    @state = Vines::Stream::Client::Auth.new(@stream)
  end

  def test_invalid_element
    node = node('<bogus/>')
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  def test_invalid_sasl_element
    node = node(%Q{<bogus xmlns="#{Vines::NAMESPACES[:sasl]}"/>})
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  def test_missing_namespace
    node = node('<auth/>')
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  def test_invalid_namespace
    node = node('<auth xmlns="bogus"/>')
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
  end

  def test_missing_mechanism
    @stream.expect(:error, nil, [Vines::SaslErrors::InvalidMechanism.new])
    node = node(%Q{<auth xmlns="#{Vines::NAMESPACES[:sasl]}">tokens</auth>})
    @state.node(node)
    assert @stream.verify
  end

  def test_invalid_mechanism
    @stream.expect(:error, nil, [Vines::SaslErrors::InvalidMechanism.new])
    node = node(%Q{<auth xmlns="#{Vines::NAMESPACES[:sasl]}" mechanism="bogus">tokens</auth>})
    @state.node(node)
    assert @stream.verify
  end

  def test_missing_text
    @stream.expect(:error, nil, [Vines::SaslErrors::MalformedRequest.new])
    node = node(%Q{<auth xmlns="#{Vines::NAMESPACES[:sasl]}" mechanism="PLAIN"></auth>})
    @state.node(node)
    assert @stream.verify
  end

  def test_plain_auth_storage_error
    @stream.expect(:storage, MockStorage.new(true))
    @stream.expect(:error, nil, [Vines::SaslErrors::TemporaryAuthFailure.new])
    node = node(%Q{<auth xmlns="#{Vines::NAMESPACES[:sasl]}" mechanism="PLAIN">tokens</auth>})
    @state.node(node)
    assert @stream.verify
  end

  def test_plain_auth_invalid_password
    @stream.expect(:storage, MockStorage.new)
    @stream.expect(:error, nil, [Vines::SaslErrors::NotAuthorized.new])
    node = node(%Q{<auth xmlns="#{Vines::NAMESPACES[:sasl]}" mechanism="PLAIN">#{Base64.encode64("alice@wonderland.lit\000\000bogus")}</auth>})
    @state.node(node)
    assert @stream.verify
  end

  def test_plain_auth_valid_password
    user = Vines::User.new(:jid => 'alice@wonderland.lit')
    @stream.expect(:reset, nil)
    @stream.expect(:storage, MockStorage.new)
    @stream.expect(:user, user)
    @stream.expect(:user=, nil, [user])
    @stream.expect(:write, nil, [%Q{<success xmlns="#{Vines::NAMESPACES[:sasl]}"/>}])
    @stream.expect(:advance, nil, [Vines::Stream::Client::BindRestart.new(@stream)])
    node = node(%Q{<auth xmlns="#{Vines::NAMESPACES[:sasl]}" mechanism="PLAIN">#{Base64.encode64("alice@wonderland.lit\000\000secr3t")}</auth>})
    @state.node(node)
    assert @stream.verify
  end

  def test_max_auth_attempts_policy_violation
    @stream.expect(:storage, MockStorage.new)
    node = proc do
      node(%Q{<auth xmlns="#{Vines::NAMESPACES[:sasl]}" mechanism="PLAIN">#{Base64.encode64("alice@wonderland.lit\000\000bogus")}</auth>})
    end

    @stream.expect(:error, nil, [Vines::SaslErrors::NotAuthorized.new])
    @state.node(node.call)
    assert @stream.verify

    @state.node(node.call)
    assert @stream.verify

    @stream.expect(:error, nil, [Vines::StreamErrors::PolicyViolation.new])
    @state.node(node.call)
    assert @stream.verify
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
