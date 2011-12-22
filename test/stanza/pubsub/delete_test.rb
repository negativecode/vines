# encoding: UTF-8

require 'tmpdir'
require 'vines'
require 'ext/nokogiri'
require 'minitest/autorun'

class DeletePubSubTest < MiniTest::Unit::TestCase
  def setup
    @user = Vines::User.new(jid: 'alice@wonderland.lit/tea')
    @config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
        pubsub 'games'
      end
    end
    @stream = MiniTest::Mock.new
    @stream.expect(:config, @config)
    @stream.expect(:user, @user)
  end

  def test_missing_to_address_raises
    node = node(%q{
      <iq type='set' id='42'>
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <delete node='game_13'/>
        </pubsub>
      </iq>
    }.strip.gsub(/\n|\s{2,}/, ''))

    @stream.expect(:domain, 'wonderland.lit')

    stanza = Vines::Stanza::PubSub::Delete.new(node, @stream)
    assert_raises(Vines::StanzaErrors::FeatureNotImplemented) { stanza.process }
    assert @stream.verify
  end

  def test_server_domain_to_address_raises
    node = node(%q{
      <iq type='set' to='wonderland.lit' id='42'>
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <delete node='game_13'/>
        </pubsub>
      </iq>
    }.strip.gsub(/\n|\s{2,}/, ''))

    stanza = Vines::Stanza::PubSub::Delete.new(node, @stream)
    assert_raises(Vines::StanzaErrors::FeatureNotImplemented) { stanza.process }
    assert @stream.verify
  end

  def test_non_pubsub_to_address_routes
    node = node(%q{
      <iq type='set' to='bogus.wonderland.lit' id='42'>
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <delete node='game_13'/>
        </pubsub>
      </iq>
    }.strip.gsub(/\n|\s{2,}/, ''))

    router = MiniTest::Mock.new
    router.expect(:route, nil, [node])
    @stream.expect(:router, router)

    stanza = Vines::Stanza::PubSub::Delete.new(node, @stream)
    stanza.process
    assert @stream.verify
    assert router.verify
  end

  def test_multiple_delete_elements_raises
    node = node(%q{
      <iq type='set' to='games.wonderland.lit' id='42'>
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <delete node='game_13'/>
          <delete node='game_14'/>
        </pubsub>
      </iq>
    }.strip.gsub(/\n|\s{2,}/, ''))

    stanza = Vines::Stanza::PubSub::Delete.new(node, @stream)
    assert_raises(Vines::StanzaErrors::BadRequest) { stanza.process }
    assert @stream.verify
  end

  def test_delete_missing_node_raises
    node = node(%q{
      <iq type='set' to='games.wonderland.lit' id='42'>
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <delete node='game_13'/>
        </pubsub>
      </iq>
    }.strip.gsub(/\n|\s{2,}/, ''))

    stanza = Vines::Stanza::PubSub::Delete.new(node, @stream)
    assert_raises(Vines::StanzaErrors::ItemNotFound) { stanza.process }
    assert @stream.verify
  end

  def test_good_stanza_processes
    node = node(%q{
      <iq type='set' to='games.wonderland.lit' id='42'>
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <delete node='game_13'/>
        </pubsub>
      </iq>
    }.strip.gsub(/\n|\s{2,}/, ''))

    def @stream.nodes; @nodes; end
    def @stream.write(node)
      @nodes ||= []
      @nodes << node
    end

    stanza = Vines::Stanza::PubSub::Delete.new(node, @stream)
    def stanza.mock_pubsub; @mock_pubsub; end
    def stanza.pubsub
      unless @mock_pubsub
        xml = %q{<message><event xmlns="http://jabber.org/protocol/pubsub#event"><delete node="game_13"/></event></message>}
        @mock_pubsub = MiniTest::Mock.new
        @mock_pubsub.expect(:node?, true, ['game_13'])
        @mock_pubsub.expect(:publish, nil, ['game_13', Nokogiri::XML(xml).root])
        @mock_pubsub.expect(:delete_node, nil, ['game_13'])
      end
      @mock_pubsub
    end
    stanza.process

    assert @stream.verify
    assert stanza.mock_pubsub.verify
    assert_equal 1, @stream.nodes.size

    expected = node(%q{<iq from="games.wonderland.lit" id="42" to="alice@wonderland.lit/tea" type="result"/>})
    assert_equal expected, @stream.nodes[0]
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
