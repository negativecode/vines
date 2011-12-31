# encoding: UTF-8

require 'tmpdir'
require 'vines'
require 'minitest/autorun'

class RouterTest < MiniTest::Unit::TestCase
  def setup
    @alice = Vines::JID.new('alice@wonderland.lit/tea')
    @config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
        components 'tea' => 'secr3t'
      end
    end
    @router = Vines::Router.new(@config)
  end

  def test_connected_resources
    cake = 'alice@wonderland.lit/cake'
    assert_equal 0, @router.connected_resources(@alice, @alice).size
    assert_equal 0, @router.connected_resources(cake, @alice).size
    assert_equal 0, @router.size

    stream1, stream2 = stream(@alice), stream(cake)
    @router << stream1
    @router << stream2

    assert_equal 1, @router.connected_resources(@alice, @alice).size
    assert_equal @alice, @router.connected_resources(@alice, @alice)[0].user.jid

    assert_equal 1, @router.connected_resources(cake, @alice).size
    assert_equal cake, @router.connected_resources(cake, @alice)[0].user.jid.to_s

    assert_equal 2, @router.connected_resources(@alice.bare, @alice).size
    assert_equal 2, @router.size
    assert stream1.verify
    assert stream2.verify
  end

  def test_connected_resources_checks_allowed
    romeo = 'romeo@verona.lit/party'
    stream1, stream2 = stream(@alice), stream(romeo)
    @router << stream1
    @router << stream2

    assert_equal 2, @router.size
    assert_equal 0, @router.connected_resources(@alice, romeo).size
    @config.vhosts['wonderland.lit'].cross_domain_messages true
    assert_equal 1, @router.connected_resources(@alice, romeo).size

    assert stream1.verify
    assert stream2.verify
  end

  def test_available_resources
    cake = 'alice@wonderland.lit/cake'
    assert_equal 0, @router.available_resources(@alice, @alice).size
    assert_equal 0, @router.available_resources(cake, @alice).size
    assert_equal 0, @router.size

    stream1, stream2 = stream(@alice), stream(cake)
    stream1.expect(:available?, true)
    stream2.expect(:available?, false)
    @router << stream1
    @router << stream2

    assert_equal 1, @router.available_resources(@alice, @alice).size
    assert_equal @alice, @router.available_resources(@alice, @alice)[0].user.jid

    assert_equal 1, @router.available_resources(cake, @alice).size
    assert_equal @alice, @router.available_resources(cake, @alice)[0].user.jid

    assert_equal 1, @router.available_resources(@alice.bare, @alice).size
    assert_equal @alice, @router.available_resources(@alice.bare, @alice)[0].user.jid

    assert_equal 2, @router.size
    assert stream1.verify
    assert stream2.verify
  end

  def test_interested_resources
    hatter = 'hatter@wonderland.lit/cake'
    assert_equal 0, @router.interested_resources(@alice, @alice).size
    assert_equal 0, @router.interested_resources(hatter, @alice).size
    assert_equal 0, @router.interested_resources(@alice, hatter, @alice).size
    assert_equal 0, @router.size

    stream1, stream2 = stream(@alice), stream(hatter)
    stream1.expect(:interested?, true)
    stream2.expect(:interested?, false)
    @router << stream1
    @router << stream2

    assert_equal 0, @router.interested_resources('bogus@wonderland.lit', @alice).size

    assert_equal 1, @router.interested_resources(@alice, hatter, @alice).size
    assert_equal 1, @router.interested_resources([@alice, hatter], @alice).size
    assert_equal @alice, @router.interested_resources(@alice, hatter, @alice)[0].user.jid

    assert_equal 0, @router.interested_resources(hatter, @alice).size
    assert_equal 0, @router.interested_resources([hatter], @alice).size

    assert_equal 1, @router.interested_resources(@alice.bare, @alice).size
    assert_equal @alice, @router.interested_resources(@alice.bare, @alice)[0].user.jid

    assert_equal 2, @router.size
    assert stream1.verify
    assert stream2.verify
  end

  def test_delete
    hatter = 'hatter@wonderland.lit/cake'
    assert_equal 0, @router.size

    stream1, stream2 = stream(@alice), stream(hatter)
    @router << stream1
    @router << stream2

    assert_equal 2, @router.size

    @router.delete(stream2)
    assert_equal 1, @router.size

    @router.delete(stream2)
    assert_equal 1, @router.size

    @router.delete(stream1)
    assert_equal 0, @router.size

    assert stream1.verify
    assert stream2.verify
  end

  def test_multiple_component_streams_are_load_balanced
    stream1 = component('tea.wonderland.lit')
    stream2 = component('tea.wonderland.lit')
    @router << stream1
    @router << stream2
    stanza = Nokogiri::XML('<message from="alice@wonderland.lit" to="tea.wonderland.lit">test</message>').root
    100.times { @router.route(stanza) }

    assert_equal 100, stream1.count + stream2.count
    assert stream1.count > 33
    assert stream2.count > 33
    assert stream1.verify
    assert stream2.verify
  end

  def test_multiple_s2s_streams_are_load_balanced
    @config.vhosts['wonderland.lit'].cross_domain_messages true
    stream1 = s2s('wonderland.lit', 'verona.lit')
    stream2 = s2s('wonderland.lit', 'verona.lit')
    @router << stream1
    @router << stream2
    stanza = Nokogiri::XML('<message from="alice@wonderland.lit" to="romeo@verona.lit">test</message>').root
    100.times { @router.route(stanza) }

    assert_equal 100, stream1.count + stream2.count
    assert stream1.count > 33
    assert stream2.count > 33
    assert stream1.verify
    assert stream2.verify
  end

  private

  def stream(jid)
    MiniTest::Mock.new.tap do |stream|
      stream.expect(:connected?, true)
      stream.expect(:stream_type, :client)
      stream.expect(:user, Vines::User.new(jid: jid))
    end
  end

  def component(jid)
    stream = MiniTest::Mock.new
    stream.expect(:stream_type, :component)
    stream.expect(:remote_domain, jid)
    stream.expect(:ready?, true)
    def stream.count; @count || 0; end
    def stream.write(stanza)
      @count ||= 0
      @count += 1
    end
    stream
  end

  def s2s(domain, remote_domain)
    stream = MiniTest::Mock.new
    stream.expect(:stream_type, :server)
    stream.expect(:domain, domain)
    stream.expect(:remote_domain, remote_domain)
    stream.expect(:ready?, true)
    def stream.count; @count || 0; end
    def stream.write(stanza)
      @count ||= 0
      @count += 1
    end
    stream
  end
end
