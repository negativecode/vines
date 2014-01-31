# encoding: UTF-8

require 'test_helper'

describe Vines::Storage::Null do
  before do
    @storage = Vines::Storage::Null.new
    @user = Vines::User.new(jid: 'alice@wonderland.lit')
    @message = Nokogiri::XML(%q{
      <message type='chat' id='purple70c423f7' from='full@wonderland.lit/resource' to='offline_user@domain.tld/resource'>
        <active xmlns='http://jabber.org/protocol/chatstates'/>
        <body>Foo</body>
      </message
    }.strip).root
  end

  def test_find_user_returns_nil
    assert_nil @storage.find_user(@user.jid)
    @storage.save_user(@user)
    assert_nil @storage.find_user(@user.jid)
  end

  def test_find_vcard_returns_nil
    assert_nil @storage.find_vcard(@user.jid)
    @storage.save_vcard(@user.jid, 'card')
    assert_nil @storage.find_vcard(@user.jid)
  end

  def test_find_fragment_returns_nil
    assert_nil @storage.find_fragment(@user.jid, 'node')
    @storage.save_fragment(@user.jid, 'node')
    assert_nil @storage.find_fragment(@user.jid, 'node')
    nil
  end

  def test_fetch_delayed_messages_return_empty
    assert_equal @storage.fetch_delayed_messages(@user.jid), []
    @storage.delay_message(@user.jid, @message)
    assert_equal @storage.fetch_delayed_messages(@user.jid), []
  end
end
