# encoding: UTF-8

require 'vines'
require 'minitest/autorun'

class ClientSessionTest < MiniTest::Unit::TestCase
  def setup
    @stream = MiniTest::Mock.new
    @stream.expect(:config, nil)
  end

  def test_equality
    one = Vines::Stream::Client::Session.new(@stream)
    two = Vines::Stream::Client::Session.new(@stream)

    assert_nil one <=> 42

    assert one == one
    assert one.eql?(one)
    assert one.hash == one.hash

    refute one == two
    refute one.eql?(two)
    refute one.hash == two.hash
  end
end
