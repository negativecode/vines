# encoding: UTF-8

require 'vines'
require 'ext/nokogiri'
require 'minitest/autorun'

class CreatePubSubTest < MiniTest::Unit::TestCase
  def setup
    @user = Vines::User.new(jid: 'alice@wonderland.lit/tea')
    @config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir '.' }
        pubsub 'games'
      end
    end
    @stream = MiniTest::Mock.new
    @stream.expect(:config, @config)
    @stream.expect(:user, @user)
  end

  def test_missing_to_address_is_ignored
    node = node(%q{
      <iq type='set' id='42'>
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <create node='game_13'/>
        </pubsub>
      </iq>
    }.strip.gsub(/\n|\s{2,}/, ''))

    stanza = Vines::Stanza::PubSub::Create.new(node, @stream)
    stanza.process
    assert @stream.verify
  end

  def test_server_domain_to_address_raises
    node = node(%q{
      <iq type='set' to='wonderland.lit' id='42'>
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <create node='game_13'/>
        </pubsub>
      </iq>
    }.strip.gsub(/\n|\s{2,}/, ''))

    @stream.expect(:domain, 'wonderland.lit')

    stanza = Vines::Stanza::PubSub::Create.new(node, @stream)
    assert_raises(Vines::StanzaErrors::FeatureNotImplemented) { stanza.process }
    assert @stream.verify
  end

  def test_non_pubsub_to_address_routes
    node = node(%q{
      <iq type='set' to='bogus.wonderland.lit' id='42'>
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <create node='game_13'/>
        </pubsub>
      </iq>
    }.strip.gsub(/\n|\s{2,}/, ''))

    router = MiniTest::Mock.new
    router.expect(:route, nil, [node])

    @stream.expect(:domain, 'wonderland.lit')
    @stream.expect(:vhost, @config.vhosts['wonderland.lit'])
    @stream.expect(:router, router)

    stanza = Vines::Stanza::PubSub::Create.new(node, @stream)
    stanza.process
    assert @stream.verify
    assert router.verify
  end

  def test_multiple_create_elements_raises
    node = node(%q{
      <iq type='set' to='games.wonderland.lit' id='42'>
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <create node='game_13'/>
          <create node='game_14'/>
        </pubsub>
      </iq>
    }.strip.gsub(/\n|\s{2,}/, ''))

    @stream.expect(:domain, 'wonderland.lit')
    @stream.expect(:vhost, @config.vhosts['wonderland.lit'])

    stanza = Vines::Stanza::PubSub::Create.new(node, @stream)
    assert_raises(Vines::StanzaErrors::BadRequest) { stanza.process }
    assert @stream.verify
  end

  def test_create_duplicate_node_raises
    node = node(%q{
      <iq type='set' to='games.wonderland.lit' id='42'>
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <create node='game_13'/>
        </pubsub>
      </iq>
    }.strip.gsub(/\n|\s{2,}/, ''))

    @stream.expect(:domain, 'wonderland.lit')
    @stream.expect(:vhost, @config.vhosts['wonderland.lit'])

    stanza = Vines::Stanza::PubSub::Create.new(node, @stream)
    def stanza.pubsub
      pubsub = MiniTest::Mock.new
      pubsub.expect(:node?, true, ['game_13'])
      pubsub
    end
    assert_raises(Vines::StanzaErrors::Conflict) { stanza.process }
    assert @stream.verify
  end

  def test_good_stanza_processes
    node = node(%q{
      <iq type='set' to='games.wonderland.lit' id='42'>
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <create node='game_13'/>
        </pubsub>
      </iq>
    }.strip.gsub(/\n|\s{2,}/, ''))

    @stream.expect(:domain, 'wonderland.lit')
    @stream.expect(:vhost, @config.vhosts['wonderland.lit'])
    def @stream.nodes; @nodes; end
    def @stream.write(node)
      @nodes ||= []
      @nodes << node
    end

    stanza = Vines::Stanza::PubSub::Create.new(node, @stream)
    stanza.process

    assert @stream.verify
    assert_equal 1, @stream.nodes.size

    expected = %q{<iq from="games.wonderland.lit" id="42" to="alice@wonderland.lit/tea" type="result">}
    expected << %q{<pubsub xmlns="http://jabber.org/protocol/pubsub"><create node="game_13"/></pubsub>}
    expected << %q{</iq>}
    expected = node(expected)
    assert_equal expected, @stream.nodes[0]
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
