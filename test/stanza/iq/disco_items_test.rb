# encoding: UTF-8

require 'vines'
require 'ext/nokogiri'
require 'minitest/autorun'

class DiscoItemsTest < MiniTest::Unit::TestCase
  def setup
    @stream = MiniTest::Mock.new
  end

  def test_component_items
    query = %q{<query xmlns="http://jabber.org/protocol/disco#items"/>}
    node = node(%Q{<iq id="42" to="wonderland.lit" type="get">#{query}</iq>})

    expected = node(%q{
      <iq from="wonderland.lit" id="42" to="alice@wonderland.lit/home" type="result">
        <query xmlns="http://jabber.org/protocol/disco#items">
          <item jid="cake.wonderland.lit"/>
          <item jid="tea.wonderland.lit"/>
        </query>
      </iq>
    }.strip.gsub(/\n|\s{2,}/, ''))

    config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir '.' }
        components 'tea' => 'secr3t', 'cake' => 'passw0rd'
      end
    end

    @stream.expect(:config, config)
    @stream.expect(:user, Vines::User.new(:jid => 'alice@wonderland.lit/home'))
    @stream.expect(:domain, 'wonderland.lit')
    @stream.expect(:write, nil, [expected])

    stanza = Vines::Stanza::Iq::DiscoItems.new(node, @stream)
    stanza.process
    assert @stream.verify
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
