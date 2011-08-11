# encoding: UTF-8

require 'vines'
require 'minitest/autorun'

class RouterTest < MiniTest::Unit::TestCase
  def setup
    @alice = Vines::JID.new('alice@wonderland.lit/tea')
    @stream = MiniTest::Mock.new
    @router = Vines::Router.new
    @config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir '.' }
      end
    end
  end

  def test_connected_resources
    assert_equal 0, @router.connected_resources(@alice, @alice).size

    @stream.expect(:config, @config)
    @stream.expect(:stream_type, :client)
    @stream.expect(:connected?, true)
    @stream.expect(:user, Vines::User.new(jid: @alice))
    @router << @stream

    assert_equal 1, @router.connected_resources(@alice, @alice).size
    assert @stream.verify
  end
end
