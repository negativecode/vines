# encoding: UTF-8

require 'test_helper'

class SessionsTest < MiniTest::Unit::TestCase
  class MockSessions < Vines::Stream::Http::Sessions
    def start_timer
      # do nothing
    end
  end

  def setup
    @sessions = MockSessions.new
  end

  def test_session_add_and_delete
    session = "session"
    assert_nil @sessions['42']
    @sessions['42'] = session
    assert_equal session, @sessions['42']
    @sessions.delete('42')
    assert_nil @sessions['42']
  end

  def test_access_singleton_through_class_methods
    session = "session"
    assert_nil MockSessions['42']
    MockSessions['42'] = session
    assert_equal session, MockSessions['42']
    MockSessions.delete('42')
    assert_nil MockSessions['42']
  end

  def test_cleanup
    live = MiniTest::Mock.new
    live.expect(:expired?, false)

    dead = MiniTest::Mock.new
    dead.expect(:expired?, true)
    dead.expect(:close, nil)

    @sessions['live'] = live
    @sessions['dead'] = dead

    @sessions.send(:cleanup)
    assert live.verify
    assert dead.verify
  end
end
