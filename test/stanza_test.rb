# encoding: UTF-8

require 'test_helper'

describe Vines::Stanza do
  subject      { Vines::Stanza::Message.new(xml, stream) }
  let(:alice)  { Vines::JID.new('alice@wonderland.lit/tea') }
  let(:romeo)  { Vines::JID.new('romeo@verona.lit/balcony') }
  let(:stream) { MiniTest::Mock.new }
  let(:config) do
    Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
      end
    end
  end

  describe 'when stanza contains no addresses' do
    let(:xml) { node(%Q{<message>hello!</message>}) }

    it 'validates them as nil' do
      subject.validate_to.must_be_nil
      subject.validate_from.must_be_nil
      stream.verify
    end
  end

  describe 'when stanza contains valid addresses' do
    let(:xml) { node(%Q{<message from="#{alice}" to="#{romeo}">hello!</message>}) }

    it 'validates and returns JID objects' do
      subject.validate_to.must_equal romeo
      subject.validate_from.must_equal alice
      stream.verify
    end
  end

  describe 'when stanza contains invalid addresses' do
    let(:xml) { node(%Q{<message from="a lice@wonderland.lit" to="romeo@v erona.lit">hello!</message>}) }

    it 'raises a jid-malformed stanza error' do
      -> { subject.validate_to }.must_raise Vines::StanzaErrors::JidMalformed
      -> { subject.validate_from }.must_raise Vines::StanzaErrors::JidMalformed
      stream.verify
    end
  end

  describe 'when receiving a non-routable stanza type' do
    let(:xml) { node('<auth/>') }

    it 'handles locally rather than routing' do
      subject.local?.must_equal true
      stream.verify
    end
  end

  describe 'when stanza is missing a to address' do
    let(:xml) { node(%Q{<message>hello!</message>}) }

    it 'handles locally rather than routing' do
      subject.local?.must_equal true
      stream.verify
    end
  end

  describe 'when stanza is addressed to a local jid' do
    let(:xml) { node(%Q{<message to="#{alice}">hello!</message>}) }

    it 'handles locally rather than routing' do
      stream.expect :config, config
      subject.local?.must_equal true
      stream.verify
    end
  end

  describe 'when stanza is addressed to a remote jid' do
    let(:xml) { node(%Q{<message to="#{romeo}">hello!</message>}) }

    it 'is not considered a local stanza' do
      stream.expect :config, config
      subject.local?.must_equal false
      stream.verify
    end
  end
end
