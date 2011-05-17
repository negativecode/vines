# encoding: UTF-8

require 'vines'
require 'minitest/autorun'

class SessionsTest < MiniTest::Unit::TestCase
  class MockSessions < Vines::Stream::Http::Sessions
    def start_timer
      # do nothing
    end
  end

  def setup
    @sessions = MockSessions.new
  end

  def test
  end
end
