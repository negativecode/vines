# encoding: UTF-8

require 'vines'
require 'ext/nokogiri'
require 'minitest/autorun'

class IqTest < MiniTest::Unit::TestCase
  def setup
    @stream = MiniTest::Mock.new
    @config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir '.' }
      end
    end
  end

  def test_allow_other_iq_to_route
    alice = Vines::User.new(:jid => 'alice@wonderland.lit/tea')
    hatter = Vines::User.new(:jid => 'hatter@wonderland.lit/crumpets')
    node = node(%q{
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
    }.strip.gsub(/\n|\s{2,}/, ''))

    recipient = MiniTest::Mock.new
    recipient.expect(:user, alice, [])
    recipient.expect(:write, nil, [node])

    @stream.expect(:config, @config)
    @stream.expect(:user, hatter)
    @stream.expect(:connected_resources, [recipient], [alice.jid.to_s])

    stanza = Vines::Stanza::Iq.new(node, @stream)
    stanza.process
    assert @stream.verify
    assert recipient.verify
  end

  def test_feature_not_implemented
    node = node('<iq type="set" id="42"/>')
    stanza = Vines::Stanza::Iq.new(node, @stream)
    assert_raises(Vines::StanzaErrors::FeatureNotImplemented) { stanza.process }
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
