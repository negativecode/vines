# encoding: UTF-8

require 'vines'
require 'ext/nokogiri'
require 'minitest/autorun'

class ProbeTest < MiniTest::Unit::TestCase
  def setup
    @alice = Vines::JID.new('alice@wonderland.lit/tea')
    @stream = MiniTest::Mock.new
    @config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir '.' }
      end
    end
  end

  def test_missing_to_address_raises
    node = node(%q{<presence id="42" type="probe"/>})
    stanza = Vines::Stanza::Presence::Probe.new(node, @stream)
    def stanza.inbound?; false; end

    @stream.expect(:user, Vines::User.new(jid: @alice))

    assert_raises(Vines::StanzaErrors::BadRequest) { stanza.process }
    assert @stream.verify
  end

  def test_to_remote_address_routes
    node = node(%q{<presence id="42" to="romeo@verona.lit" type="probe"/>})
    stanza = Vines::Stanza::Presence::Probe.new(node, @stream)
    def stanza.inbound?; false; end

    expected = node(%Q{<presence id="42" to="romeo@verona.lit" type="probe" from="#{@alice}"/>})
    router = MiniTest::Mock.new
    router.expect(:route, nil, [expected])

    @stream.expect(:router, router)
    @stream.expect(:user, Vines::User.new(jid: @alice))
    @stream.expect(:config, @config)

    stanza.process
    assert @stream.verify
    assert router.verify
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
