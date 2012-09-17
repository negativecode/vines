# encoding: UTF-8

require 'test_helper'

describe Vines::Stream::Client::Auth do
  # disable logging for tests
  Class.new.extend(Vines::Log).log.level = Logger::FATAL

  class MockStorage < Vines::Storage
    def initialize(raise_error=false)
      @raise_error = raise_error
    end

    def authenticate(username, password)
      username = username.to_s
      raise 'temp auth fail' if @raise_error
      user = Vines::User.new(jid: 'alice@wonderland.lit')
      users = {'alice@wonderland.lit' => 'secr3t'}
      (users.key?(username) && (users[username] == password)) ? user : nil
    end

    def find_user(jid)
    end

    def save_user(user)
    end
  end

  subject      { Vines::Stream::Client::Auth.new(stream) }
  let(:stream) { MiniTest::Mock.new }

  describe 'error handling' do
    it 'rejects invalid element' do
      node = node('<bogus/>')
      -> { subject.node(node) }.must_raise Vines::StreamErrors::NotAuthorized
    end

    it 'rejects invalid element in sasl namespace' do
      node = node(%Q{<bogus xmlns="#{Vines::NAMESPACES[:sasl]}"/>})
      -> { subject.node(node) }.must_raise Vines::StreamErrors::NotAuthorized
    end

    it 'rejects auth elements missing sasl namespace' do
      node = node('<auth/>')
      -> { subject.node(node) }.must_raise Vines::StreamErrors::NotAuthorized
    end

    it 'rejects auth element with invalid namespace' do
      node = node('<auth xmlns="bogus"/>')
      -> { subject.node(node) }.must_raise Vines::StreamErrors::NotAuthorized
    end

    it 'rejects valid auth element missing mechanism' do
      stream.expect :error, nil, [Vines::SaslErrors::InvalidMechanism]
      stream.expect :authentication_mechanisms, ['PLAIN']
      node = node(%Q{<auth xmlns="#{Vines::NAMESPACES[:sasl]}">tokens</auth>})
      subject.node(node)
      stream.verify
    end

    it 'rejects valid auth element with invalid mechanism' do
      stream.expect :error, nil, [Vines::SaslErrors::InvalidMechanism]
      stream.expect :authentication_mechanisms, ['PLAIN']
      node = node(%Q{<auth xmlns="#{Vines::NAMESPACES[:sasl]}" mechanism="bogus">tokens</auth>})
      subject.node(node)
      stream.verify
    end
  end

  describe 'plain auth' do
    it 'rejects valid mechanism missing base64 text' do
      stream.expect :error, nil, [Vines::SaslErrors::MalformedRequest]
      node = plain('')
      subject.node(node)
      stream.verify
    end

    it 'rejects invalid base64 text' do
      stream.expect :error, nil, [Vines::SaslErrors::IncorrectEncoding]
      stream.expect :authentication_mechanisms, ['PLAIN']
      node = plain('tokens')
      subject.node(node)
      stream.verify
    end

    it 'rejects invalid password' do
      stream.expect :storage, MockStorage.new
      stream.expect :domain, 'wonderland.lit'
      stream.expect :error, nil, [Vines::SaslErrors::NotAuthorized]
      stream.expect :authentication_mechanisms, ['PLAIN']
      node = plain(Base64.strict_encode64("\x00alice\x00bogus"))
      subject.node(node)
      stream.verify
    end

    it 'passes with valid password' do
      user = Vines::User.new(jid: 'alice@wonderland.lit')
      stream.expect :reset, nil
      stream.expect :domain, 'wonderland.lit'
      stream.expect :storage, MockStorage.new
      stream.expect :user=, nil, [user]
      stream.expect :write, nil, [%Q{<success xmlns="#{Vines::NAMESPACES[:sasl]}"/>}]
      stream.expect :advance, nil, [Vines::Stream::Client::BindRestart]
      stream.expect :authentication_mechanisms, ['PLAIN']
      node = plain(Base64.strict_encode64("\x00alice\x00secr3t"))
      subject.node(node)
      stream.verify
    end

    it 'raises policy-violation after max auth attempts is reached' do
      stream.expect :domain, 'wonderland.lit'
      stream.expect :storage, MockStorage.new
      node = -> { plain(Base64.strict_encode64("\x00alice\x00bogus")) }

      stream.expect :authentication_mechanisms, ['PLAIN']
      stream.expect :error, nil, [Vines::SaslErrors::NotAuthorized]
      subject.node(node.call)
      stream.verify

      stream.expect :authentication_mechanisms, ['PLAIN']
      stream.expect :error, nil, [Vines::SaslErrors::NotAuthorized]
      subject.node(node.call)
      stream.verify

      stream.expect :authentication_mechanisms, ['PLAIN']
      stream.expect :error, nil, [Vines::StreamErrors::PolicyViolation]
      subject.node(node.call)
      stream.verify
    end
  end

  private

  def plain(authzid)
    node(%Q{<auth xmlns="#{Vines::NAMESPACES[:sasl]}" mechanism="PLAIN">#{authzid}</auth>})
  end
end
