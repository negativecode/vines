# encoding: UTF-8

require 'test_helper'

describe Vines::Stanza::Iq::DiscoInfo do
  subject      { Vines::Stanza::Iq::DiscoInfo.new(xml, stream) }
  let(:stream) { MiniTest::Mock.new }
  let(:alice)  { Vines::User.new(jid: 'alice@wonderland.lit/home') }
  let(:config) do
    Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
      end
    end
  end

  let(:xml) do
    query = %q{<query xmlns="http://jabber.org/protocol/disco#info"/>}
    node(%Q{<iq id="42" to="wonderland.lit" type="get">#{query}</iq>})
  end

  before do
    class << stream
      attr_accessor :config, :user
    end
    stream.config = config
    stream.user = alice
  end

  describe 'when private storage is disabled' do
    let(:expected) do
      node(%Q{
        <iq from="wonderland.lit" id="42" to="#{alice.jid}" type="result">
          <query xmlns="http://jabber.org/protocol/disco#info">
            <identity category="server" type="im"/>
            <feature var="http://jabber.org/protocol/disco#info"/>
            <feature var="http://jabber.org/protocol/disco#items"/>
            <feature var="urn:xmpp:ping"/>
            <feature var="vcard-temp"/>
            <feature var="jabber:iq:version"/>
          </query>
        </iq>
      })
    end

    it 'returns info stanza without the private storage feature' do
      config.vhost('wonderland.lit').private_storage false
      stream.expect :write, nil, [expected]
      subject.process
      stream.verify
    end
  end

  describe 'when private storage is enabled' do
    let(:expected) do
      node(%Q{
        <iq from="wonderland.lit" id="42" to="#{alice.jid}" type="result">
          <query xmlns="http://jabber.org/protocol/disco#info">
            <identity category="server" type="im"/>
            <feature var="http://jabber.org/protocol/disco#info"/>
            <feature var="http://jabber.org/protocol/disco#items"/>
            <feature var="urn:xmpp:ping"/>
            <feature var="vcard-temp"/>
            <feature var="jabber:iq:version"/>
            <feature var="jabber:iq:private"/>
          </query>
        </iq>
      })
    end

    it 'announces private storage feature in info stanza result' do
      config.vhost('wonderland.lit').private_storage true
      stream.expect :write, nil, [expected]
      subject.process
      stream.verify
    end
  end
end
