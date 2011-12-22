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

  private

  def stream(jid)
    MiniTest::Mock.new.tap do |stream|
      stream.expect(:connected?, true)
      stream.expect(:stream_type, :client)
      stream.expect(:user, Vines::User.new(jid: jid))
    end
  end
end
