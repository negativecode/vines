# encoding: UTF-8

require 'test_helper'

describe Vines::Stanza::Iq do
  subject      { Vines::Stanza::Iq.new(xml, stream) }
  let(:stream) { MiniTest::Mock.new }
  let(:alice)  { Vines::User.new(jid: 'alice@wonderland.lit/tea') }
  let(:hatter) { Vines::User.new(jid: 'hatter@wonderland.lit/crumpets') }
  let(:config) do
    Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
      end
    end
  end

  before do
    class << stream
      attr_accessor :config, :user
    end
    stream.user = hatter
    stream.config = config
  end

  describe 'when addressed to a user rather than the server itself' do
    let(:recipient) { MiniTest::Mock.new }
    let(:xml) do
      node(%q{
        <iq id="42" type="set" to="alice@wonderland.lit/tea" from="hatter@wonderland.lit/crumpets">
            <si xmlns="http://jabber.org/protocol/si" id="42_si" profile="http://jabber.org/protocol/si/profile/file-transfer">
              <file xmlns="http://jabber.org/protocol/si/profile/file-transfer" name="file" size="1"/>
              <feature xmlns="http://jabber.org/protocol/feature-neg">
                <x xmlns="jabber:x:data" type="form">
                  <field var="stream-method" type="list-single">
                    <option>
                      <value>http://jabber.org/protocol/bytestreams</value>
                    </option>
                    <option>
                      <value>http://jabber.org/protocol/ibb</value>
                    </option>
                  </field>
                </x>
              </feature>
            </si>
          </iq>
      })
    end

    before do
      recipient.expect :user, alice, []
      recipient.expect :write, nil, [xml]
      stream.expect :connected_resources, [recipient], [alice.jid]
    end

    it 'routes the stanza to the users connected resources' do
      subject.process
      stream.verify
      recipient.verify
    end
  end

  describe 'when given no type or body elements' do
    let(:xml) { node('<iq type="set" id="42"/>') }

    it 'raises a feature-not-implemented stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::FeatureNotImplemented
    end
  end
end
