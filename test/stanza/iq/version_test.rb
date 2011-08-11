# encoding: UTF-8

require 'vines'
require 'ext/nokogiri'
require 'minitest/autorun'

class VersionTest < MiniTest::Unit::TestCase
  def setup
    @stream = MiniTest::Mock.new
    @config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir '.' }
      end
    end
  end

  def test_to_address_routes
    alice = Vines::User.new(:jid => 'alice@wonderland.lit/tea')
    node = node(%q{<iq id="42" to="romeo@verona.lit" type="get"><query xmlns="jabber:iq:version"/></iq>})

    router = MiniTest::Mock.new
    router.expect(:route, nil, [node])

    @stream.expect(:domain, 'wonderland.lit')
    @stream.expect(:config, @config)
    @stream.expect(:user, alice)
    @stream.expect(:router, router)

    stanza = Vines::Stanza::Iq::Version.new(node, @stream)
    stanza.process
    assert @stream.verify
    assert router.verify
  end

  def test_version_get_returns_result
    alice = Vines::User.new(:jid => 'alice@wonderland.lit/tea')
    node = node(%q{<iq id="42" type="get"><query xmlns="jabber:iq:version"/></iq>})

    @stream.expect(:user, alice)
    @stream.expect(:domain, 'wonderland.lit')

    expected = node(%Q{
      <iq from="wonderland.lit" id="42" to="alice@wonderland.lit/tea" type="result">
        <query xmlns="jabber:iq:version">
          <name>Vines</name>
          <version>#{Vines::VERSION}</version>
        </query>
      </iq>}.strip.gsub(/\n|\s{2,}/, ''))

    @stream.expect(:write, nil, [expected])

    stanza = Vines::Stanza::Iq::Version.new(node, @stream)
    stanza.process
    assert @stream.verify
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
