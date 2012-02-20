# encoding: UTF-8

require 'tmpdir'
require 'vines'
require 'ext/nokogiri'
require 'minitest/autorun'

class PrivateStorageTest < MiniTest::Unit::TestCase
  def setup
    @stream = MiniTest::Mock.new
    @config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
        private_storage true
      end
    end
  end

  def test_feature_disabled_raises_error
    query = %q{<query xmlns="jabber:iq:private"><one xmlns="a"/></query>}
    node = node(%Q{<iq id="42" type="get">#{query}</iq>})

    @config.vhost('wonderland.lit').private_storage false
    @stream.expect(:domain, 'wonderland.lit')
    @stream.expect(:config, @config)

    stanza = Vines::Stanza::Iq::PrivateStorage.new(node, @stream)
    assert_raises(Vines::StanzaErrors::ServiceUnavailable) { stanza.process }
    assert @stream.verify
  end

  def test_get_another_user_fragment_raises_error
    alice = Vines::User.new(:jid => 'alice@wonderland.lit/tea')
    query = %q{<query xmlns="jabber:iq:private"><one xmlns="a"/></query>}
    node = node(%Q{<iq id="42" to="hatter@wonderland.lit" type="get">#{query}</iq>})

    @stream.expect(:user, alice)

    stanza = Vines::Stanza::Iq::PrivateStorage.new(node, @stream)
    assert_raises(Vines::StanzaErrors::Forbidden) { stanza.process }
    assert @stream.verify
  end

  def test_get_with_zero_children_raises_error
    alice = Vines::User.new(:jid => 'alice@wonderland.lit/tea')
    query = %q{<query xmlns="jabber:iq:private"></query>}
    node = node(%Q{<iq id="42" type="get">#{query}</iq>})

    @stream.expect(:domain, 'wonderland.lit')
    @stream.expect(:config, @config)

    stanza = Vines::Stanza::Iq::PrivateStorage.new(node, @stream)
    assert_raises(Vines::StanzaErrors::NotAcceptable) { stanza.process }
    assert @stream.verify
  end

  def test_get_with_two_children_raises_error
    alice = Vines::User.new(:jid => 'alice@wonderland.lit/tea')
    query = %q{<query xmlns="jabber:iq:private"><one xmlns="a"/><two xmlns="b"/></query>}
    node = node(%Q{<iq id="42" type="get">#{query}</iq>})

    @stream.expect(:domain, 'wonderland.lit')
    @stream.expect(:config, @config)

    stanza = Vines::Stanza::Iq::PrivateStorage.new(node, @stream)
    assert_raises(Vines::StanzaErrors::NotAcceptable) { stanza.process }
    assert @stream.verify
  end

  def test_set_with_zero_children_raises_error
    alice = Vines::User.new(:jid => 'alice@wonderland.lit/tea')
    query = %q{<query xmlns="jabber:iq:private"></query>}
    node = node(%Q{<iq id="42" type="set">#{query}</iq>})

    @stream.expect(:domain, 'wonderland.lit')
    @stream.expect(:config, @config)

    stanza = Vines::Stanza::Iq::PrivateStorage.new(node, @stream)
    assert_raises(Vines::StanzaErrors::NotAcceptable) { stanza.process }
    assert @stream.verify
  end

  def test_get_without_namespace_raises_error
    alice = Vines::User.new(:jid => 'alice@wonderland.lit/tea')
    query = %q{<query xmlns="jabber:iq:private"><one/></query>}
    node = node(%Q{<iq id="42" type="get">#{query}</iq>})

    @stream.expect(:domain, 'wonderland.lit')
    @stream.expect(:config, @config)

    stanza = Vines::Stanza::Iq::PrivateStorage.new(node, @stream)
    assert_raises(Vines::StanzaErrors::NotAcceptable) { stanza.process }
    assert @stream.verify
  end

  def test_get_missing_fragment_raises_error
    alice = Vines::User.new(:jid => 'alice@wonderland.lit/tea')
    query = %q{<query xmlns="jabber:iq:private"><one xmlns="a"/></query>}
    node = node(%Q{<iq id="42" type="get">#{query}</iq>})

    storage = MiniTest::Mock.new
    storage.expect(:find_fragment, nil, [alice.jid, node.elements[0].elements[0]])

    @stream.expect(:domain, 'wonderland.lit')
    @stream.expect(:config, @config)
    @stream.expect(:storage, storage, ['wonderland.lit'])
    @stream.expect(:user, alice)

    stanza = Vines::Stanza::Iq::PrivateStorage.new(node, @stream)
    assert_raises(Vines::StanzaErrors::ItemNotFound) { stanza.process }
    assert @stream.verify
    assert storage.verify
  end

  def test_get_finds_fragment_writes_to_stream
    alice = Vines::User.new(:jid => 'alice@wonderland.lit/tea')
    query = %q{<query xmlns="jabber:iq:private"><one xmlns="a"/></query>}
    node = node(%Q{<iq id="42" type="get">#{query}</iq>})

    data = %q{<one xmlns="a"><child>data</child></one>}
    query = %Q{<query xmlns="jabber:iq:private">#{data}</query>}
    expected = node(%Q{<iq from="#{alice.jid}" id="42" to="#{alice.jid}" type="result">#{query}</iq>})

    storage = MiniTest::Mock.new
    storage.expect(:find_fragment, node(data), [alice.jid, node.elements[0].elements[0]])

    @stream.expect(:domain, 'wonderland.lit')
    @stream.expect(:config, @config)
    @stream.expect(:storage, storage, ['wonderland.lit'])
    @stream.expect(:user, alice)
    @stream.expect(:write, nil, [expected])

    stanza = Vines::Stanza::Iq::PrivateStorage.new(node, @stream)
    stanza.process
    assert @stream.verify
    assert storage.verify
  end

  def test_set_one_fragment_writes_result_to_stream
    alice = Vines::User.new(:jid => 'alice@wonderland.lit/tea')
    query = %q{<query xmlns="jabber:iq:private"><one xmlns="a"/></query>}
    node = node(%Q{<iq id="42" type="set">#{query}</iq>})

    storage = MiniTest::Mock.new
    storage.expect(:save_fragment, nil, [alice.jid, node.elements[0].elements[0]])

    expected = node(%Q{<iq from="#{alice.jid}" id="42" to="#{alice.jid}" type="result"/>})

    @stream.expect(:domain, 'wonderland.lit')
    @stream.expect(:config, @config)
    @stream.expect(:storage, storage, ['wonderland.lit'])
    @stream.expect(:user, alice)
    @stream.expect(:write, nil, [expected])

    stanza = Vines::Stanza::Iq::PrivateStorage.new(node, @stream)
    stanza.process
    assert @stream.verify
    assert storage.verify
  end

  def test_set_two_fragments_writes_result_to_stream
    alice = Vines::User.new(:jid => 'alice@wonderland.lit/tea')
    query = %q{<query xmlns="jabber:iq:private"><one xmlns="a"/><two xmlns="a"/></query>}
    node = node(%Q{<iq id="42" type="set">#{query}</iq>})

    storage = MiniTest::Mock.new
    storage.expect(:save_fragment, nil, [alice.jid, node.elements[0].elements[0]])
    storage.expect(:save_fragment, nil, [alice.jid, node.elements[0].elements[1]])

    expected = node(%Q{<iq from="#{alice.jid}" id="42" to="#{alice.jid}" type="result"/>})

    @stream.expect(:domain, 'wonderland.lit')
    @stream.expect(:config, @config)
    @stream.expect(:storage, storage, ['wonderland.lit'])
    @stream.expect(:user, alice)
    @stream.expect(:write, nil, [expected])

    stanza = Vines::Stanza::Iq::PrivateStorage.new(node, @stream)
    stanza.process
    assert @stream.verify
    assert storage.verify
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
