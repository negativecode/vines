# encoding: UTF-8

require 'vines'
require 'ext/nokogiri'
require 'minitest/autorun'

class UnsubscribePubSubTest < MiniTest::Unit::TestCase
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
          <unsubscribe node='game_13' jid="alice@wonderland.lit/tea"/>
        </pubsub>
      </iq>
    }.strip.gsub(/\n|\s{2,}/, ''))

    stanza = Vines::Stanza::PubSub::Unsubscribe.new(node, @stream)
    stanza.process
    assert @stream.verify
  end

  def test_server_domain_to_address_raises
    node = node(%q{
      <iq type='set' to='wonderland.lit' id='42'>
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <unsubscribe node='game_13' jid="alice@wonderland.lit/tea"/>
        </pubsub>
      </iq>
    }.strip.gsub(/\n|\s{2,}/, ''))

    @stream.expect(:domain, 'wonderland.lit')

    stanza = Vines::Stanza::PubSub::Unsubscribe.new(node, @stream)
    assert_raises(Vines::StanzaErrors::FeatureNotImplemented) { stanza.process }
    assert @stream.verify
  end

  def test_non_pubsub_to_address_routes
    node = node(%q{
      <iq type='set' to='bogus.wonderland.lit' id='42'>
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <unsubscribe node='game_13' jid="alice@wonderland.lit/tea"/>
        </pubsub>
      </iq>
    }.strip.gsub(/\n|\s{2,}/, ''))

    router = MiniTest::Mock.new
    router.expect(:route, nil, [node])

    @stream.expect(:domain, 'wonderland.lit')
    @stream.expect(:vhost, @config.vhosts['wonderland.lit'])
    @stream.expect(:router, router)

    stanza = Vines::Stanza::PubSub::Unsubscribe.new(node, @stream)
    stanza.process
    assert @stream.verify
    assert router.verify
  end

  def test_multiple_unsubscribe_elements_raises
    node = node(%q{
      <iq type='set' to='games.wonderland.lit' id='42'>
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <unsubscribe node='game_13' jid="alice@wonderland.lit/tea"/>
          <unsubscribe node='game_14' jid="alice@wonderland.lit/tea"/>
        </pubsub>
      </iq>
    }.strip.gsub(/\n|\s{2,}/, ''))

    @stream.expect(:domain, 'wonderland.lit')
    @stream.expect(:vhost, @config.vhosts['wonderland.lit'])

    stanza = Vines::Stanza::PubSub::Unsubscribe.new(node, @stream)
    assert_raises(Vines::StanzaErrors::BadRequest) { stanza.process }
    assert @stream.verify
  end

  def test_unsubscribe_missing_node_raises
    node = node(%q{
      <iq type='set' to='games.wonderland.lit' id='42'>
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <unsubscribe node='game_13' jid="alice@wonderland.lit/tea"/>
        </pubsub>
      </iq>
    }.strip.gsub(/\n|\s{2,}/, ''))

    @stream.expect(:domain, 'wonderland.lit')
    @stream.expect(:vhost, @config.vhosts['wonderland.lit'])

    stanza = Vines::Stanza::PubSub::Unsubscribe.new(node, @stream)
    assert_raises(Vines::StanzaErrors::ItemNotFound) { stanza.process }
    assert @stream.verify
  end

  def test_unsubscribe_without_subscription_raises
    node = node(%q{
      <iq type='set' to='games.wonderland.lit' id='42'>
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <unsubscribe node='game_13' jid="alice@wonderland.lit/tea"/>
        </pubsub>
      </iq>
    }.strip.gsub(/\n|\s{2,}/, ''))

    @stream.expect(:domain, 'wonderland.lit')
    @stream.expect(:vhost, @config.vhosts['wonderland.lit'])

    stanza = Vines::Stanza::PubSub::Unsubscribe.new(node, @stream)
    def stanza.mock_pubsub; @mock_pubsub; end
    def stanza.pubsub
      unless @mock_pubsub
        @mock_pubsub = MiniTest::Mock.new
        @mock_pubsub.expect(:node?, true, ['game_13'])
        @mock_pubsub.expect(:subscribed?, false, ['game_13', 'alice@wonderland.lit/tea'])
      end
      @mock_pubsub
    end
    assert_raises(Vines::StanzaErrors::UnexpectedRequest) { stanza.process }
    assert @stream.verify
    assert stanza.mock_pubsub.verify
  end

  def test_unsubscribe_illegal_jid_raises
    node = node(%q{
      <iq type='set' to='games.wonderland.lit' id='42'>
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <unsubscribe node='game_13' jid="not_alice@wonderland.lit/tea"/>
        </pubsub>
      </iq>
    }.strip.gsub(/\n|\s{2,}/, ''))

    @stream.expect(:domain, 'wonderland.lit')
    @stream.expect(:vhost, @config.vhosts['wonderland.lit'])

    stanza = Vines::Stanza::PubSub::Unsubscribe.new(node, @stream)
    assert_raises(Vines::StanzaErrors::Forbidden) { stanza.process }
    assert @stream.verify
  end

  def test_good_stanza_processes
    node = node(%q{
      <iq type='set' to='games.wonderland.lit' id='42'>
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <unsubscribe node='game_13' jid="alice@wonderland.lit/tea"/>
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

    stanza = Vines::Stanza::PubSub::Unsubscribe.new(node, @stream)
    def stanza.mock_pubsub; @mock_pubsub; end
    def stanza.pubsub
      unless @mock_pubsub
        @mock_pubsub = MiniTest::Mock.new
        @mock_pubsub.expect(:node?, true, ['game_13'])
        @mock_pubsub.expect(:subscribed?, true, ['game_13', 'alice@wonderland.lit/tea'])
        @mock_pubsub.expect(:unsubscribe, nil, ['game_13', 'alice@wonderland.lit/tea'])
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
