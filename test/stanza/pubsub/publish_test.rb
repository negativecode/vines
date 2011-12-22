# encoding: UTF-8

require 'tmpdir'
require 'vines'
require 'ext/nokogiri'
require 'minitest/autorun'

class PublishPubSubTest < MiniTest::Unit::TestCase
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
          <publish node='game_13'>
            <item id='item_42'>
              <entry xmlns='http://www.w3.org/2005/Atom'>
                <title>Test</title>
                <summary>This is a summary.</summary>
              </entry>
            </item>
          </publish>
        </pubsub>
      </iq>
    }.strip.gsub(/\n|\s{2,}/, ''))

    @stream.expect(:domain, 'wonderland.lit')

    stanza = Vines::Stanza::PubSub::Publish.new(node, @stream)
    assert_raises(Vines::StanzaErrors::FeatureNotImplemented) { stanza.process }
    assert @stream.verify
  end

  def test_server_domain_to_address_raises
    node = node(%q{
      <iq type='set' to='wonderland.lit' id='42'>
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <publish node='game_13'>
            <item id='item_42'>
              <entry xmlns='http://www.w3.org/2005/Atom'>
                <title>Test</title>
                <summary>This is a summary.</summary>
              </entry>
            </item>
          </publish>
        </pubsub>
      </iq>
    }.strip.gsub(/\n|\s{2,}/, ''))

    stanza = Vines::Stanza::PubSub::Publish.new(node, @stream)
    assert_raises(Vines::StanzaErrors::FeatureNotImplemented) { stanza.process }
    assert @stream.verify
  end

  def test_non_pubsub_to_address_routes
    node = node(%q{
      <iq type='set' to='bogus.wonderland.lit' id='42'>
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <publish node='game_13'>
            <item id='item_42'>
              <entry xmlns='http://www.w3.org/2005/Atom'>
                <title>Test</title>
                <summary>This is a summary.</summary>
              </entry>
            </item>
          </publish>
        </pubsub>
      </iq>
    }.strip.gsub(/\n|\s{2,}/, ''))

    router = MiniTest::Mock.new
    router.expect(:route, nil, [node])
    @stream.expect(:router, router)

    stanza = Vines::Stanza::PubSub::Publish.new(node, @stream)
    stanza.process
    assert @stream.verify
    assert router.verify
  end

  def test_multiple_publish_elements_raises
    node = node(%q{
      <iq type='set' to='games.wonderland.lit' id='42'>
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <publish node='game_13'>
            <item id='item_42'>
              <entry xmlns='http://www.w3.org/2005/Atom'>
                <title>Test</title>
                <summary>This is a summary.</summary>
              </entry>
            </item>
          </publish>
          <publish node='game_13'>
            <item id='item_42'>
              <entry xmlns='http://www.w3.org/2005/Atom'>
                <title>Test</title>
                <summary>This is a summary.</summary>
              </entry>
            </item>
          </publish>
        </pubsub>
      </iq>
    }.strip.gsub(/\n|\s{2,}/, ''))

    stanza = Vines::Stanza::PubSub::Publish.new(node, @stream)
    assert_raises(Vines::StanzaErrors::BadRequest) { stanza.process }
    assert @stream.verify
  end

  def test_multiple_item_elements_raises
    node = node(%q{
      <iq type='set' to='games.wonderland.lit' id='42'>
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <publish node='game_13'>
            <item id='item_42'>
              <entry xmlns='http://www.w3.org/2005/Atom'>
                <title>Test</title>
                <summary>This is a summary.</summary>
              </entry>
            </item>
            <item id="item_43">bad</item>
          </publish>
        </pubsub>
      </iq>
    }.strip.gsub(/\n|\s{2,}/, ''))

    stanza = Vines::Stanza::PubSub::Publish.new(node, @stream)
    def stanza.mock_pubsub; @mock_pubsub; end
    def stanza.pubsub
      unless @mock_pubsub
        @mock_pubsub = MiniTest::Mock.new
        @mock_pubsub.expect(:node?, true, ['game_13'])
      end
      @mock_pubsub
    end
    assert_raises(Vines::StanzaErrors::BadRequest) { stanza.process }
    assert @stream.verify
    assert stanza.mock_pubsub.verify
  end

  def test_multiple_payload_elements_raises
    node = node(%q{
      <iq type='set' to='games.wonderland.lit' id='42'>
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <publish node='game_13'>
            <item id='item_42'>
              <entry xmlns='http://www.w3.org/2005/Atom'>
                <title>Test</title>
                <summary>This is a summary.</summary>
              </entry>
              <entry>bad</entry>
            </item>
          </publish>
        </pubsub>
      </iq>
    }.strip.gsub(/\n|\s{2,}/, ''))

    stanza = Vines::Stanza::PubSub::Publish.new(node, @stream)
    def stanza.mock_pubsub; @mock_pubsub; end
    def stanza.pubsub
      unless @mock_pubsub
        @mock_pubsub = MiniTest::Mock.new
        @mock_pubsub.expect(:node?, true, ['game_13'])
      end
      @mock_pubsub
    end
    assert_raises(Vines::StanzaErrors::BadRequest) { stanza.process }
    assert @stream.verify
    assert stanza.mock_pubsub.verify
  end

  def test_no_payload_elements_raises
    node = node(%q{
      <iq type='set' to='games.wonderland.lit' id='42'>
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <publish node='game_13'>
            <item id='item_42'>
            </item>
          </publish>
        </pubsub>
      </iq>
    }.strip.gsub(/\n|\s{2,}/, ''))

    stanza = Vines::Stanza::PubSub::Publish.new(node, @stream)
    def stanza.mock_pubsub; @mock_pubsub; end
    def stanza.pubsub
      unless @mock_pubsub
        @mock_pubsub = MiniTest::Mock.new
        @mock_pubsub.expect(:node?, true, ['game_13'])
      end
      @mock_pubsub
    end

    assert_raises(Vines::StanzaErrors::BadRequest) { stanza.process }
    assert @stream.verify
    assert stanza.mock_pubsub.verify
  end

  def test_publish_to_missing_node_raises
    node = node(%q{
      <iq type='set' to='games.wonderland.lit' id='42'>
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <publish node='game_13'>
            <item id='item_42'>
              <entry xmlns='http://www.w3.org/2005/Atom'>
                <title>Test</title>
                <summary>This is a summary.</summary>
              </entry>
            </item>
          </publish>
        </pubsub>
      </iq>
    }.strip.gsub(/\n|\s{2,}/, ''))

    stanza = Vines::Stanza::PubSub::Publish.new(node, @stream)
    assert_raises(Vines::StanzaErrors::ItemNotFound) { stanza.process }
    assert @stream.verify
  end

  def test_generate_item_id
    node = node(%q{
      <iq type='set' to='games.wonderland.lit' id='42'>
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <publish node='game_13'>
            <item>
              <entry xmlns='http://www.w3.org/2005/Atom'>
                <title>Test</title>
                <summary>This is a summary.</summary>
              </entry>
            </item>
          </publish>
        </pubsub>
      </iq>
    }.strip.gsub(/\n|\s{2,}/, ''))

    def @stream.nodes; @nodes; end
    def @stream.write(node)
      @nodes ||= []
      @nodes << node
    end

    stanza = Vines::Stanza::PubSub::Publish.new(node, @stream)
    def stanza.mock_pubsub; @mock_pubsub; end
    def stanza.pubsub
      unless @mock_pubsub
        @mock_pubsub = MiniTest::Mock.new
        @mock_pubsub.expect(:node?, true, ['game_13'])
        def @mock_pubsub.published; @published; end
        def @mock_pubsub.publish(node, message)
          @published ||= []
          @published << [node, message]
        end
      end
      @mock_pubsub
    end
    stanza.process

    assert @stream.verify
    assert stanza.mock_pubsub.verify
    assert_equal 1, @stream.nodes.size

    # test result stanza contains generated item id
    expected = node(%q{
      <iq from="games.wonderland.lit" id="42" to="alice@wonderland.lit/tea" type="result">
        <pubsub xmlns="http://jabber.org/protocol/pubsub">
          <publish node="game_13">
            <item/>
          </publish>
        </pubsub>
      </iq>}.strip.gsub(/\n|\s{2,}/, ''))
      # id is random
      item = @stream.nodes[0].xpath('ns:pubsub/ns:publish/ns:item', 'ns' => 'http://jabber.org/protocol/pubsub').first
      refute_nil item['id']
      item.remove_attribute('id')
      assert_equal expected, @stream.nodes[0]

      # test published message has a generated item id
      expected = node(%q{
        <message>
          <event xmlns="http://jabber.org/protocol/pubsub#event">
            <items node="game_13">
              <item publisher="alice@wonderland.lit/tea">
                <entry xmlns="http://www.w3.org/2005/Atom">
                  <title>Test</title>
                  <summary>This is a summary.</summary>
                </entry>
              </item>
            </items>
          </event>
        </message>
      }.strip.gsub(/\n|\s{2,}/, ''))
      published_node, published_message = *stanza.mock_pubsub.published[0]
      assert_equal 'game_13', published_node
      # id is random
      item = published_message.xpath('ns:event/ns:items/ns:item', 'ns' => 'http://jabber.org/protocol/pubsub#event').first
      refute_nil item['id']
      item.remove_attribute('id')
      assert_equal expected, published_message
  end

  def test_good_stanza_processes
    node = node(%q{
      <iq type='set' to='games.wonderland.lit' id='42'>
        <pubsub xmlns='http://jabber.org/protocol/pubsub'>
          <publish node='game_13'>
            <item id='item_42'>
              <entry xmlns='http://www.w3.org/2005/Atom'>
                <title>Test</title>
                <summary>This is a summary.</summary>
              </entry>
            </item>
          </publish>
        </pubsub>
      </iq>
    }.strip.gsub(/\n|\s{2,}/, ''))

    def @stream.nodes; @nodes; end
    def @stream.write(node)
      @nodes ||= []
      @nodes << node
    end

    stanza = Vines::Stanza::PubSub::Publish.new(node, @stream)
    def stanza.mock_pubsub; @mock_pubsub; end
    def stanza.pubsub
      unless @mock_pubsub
        xml = %q{
          <message>
            <event xmlns="http://jabber.org/protocol/pubsub#event">
              <items node="game_13">
                <item id="item_42" publisher="alice@wonderland.lit/tea">
                  <entry xmlns="http://www.w3.org/2005/Atom">
                    <title>Test</title>
                    <summary>This is a summary.</summary>
                  </entry>
                </item>
              </items>
            </event>
          </message>
        }.strip.gsub(/\n|\s{2,}/, '')
        @mock_pubsub = MiniTest::Mock.new
        @mock_pubsub.expect(:node?, true, ['game_13'])
        @mock_pubsub.expect(:publish, nil, ['game_13', Nokogiri::XML(xml).root])
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
