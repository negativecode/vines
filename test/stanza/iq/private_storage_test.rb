# encoding: UTF-8

require 'test_helper'

describe Vines::Stanza::Iq::PrivateStorage do
  subject       { Vines::Stanza::Iq::PrivateStorage.new(xml, stream) }
  let(:alice)   { Vines::User.new(jid:  'alice@wonderland.lit/tea') }
  let(:storage) { MiniTest::Mock.new }
  let(:stream)  { MiniTest::Mock.new }
  let(:config) do
    Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
        private_storage true
      end
    end
  end

  before do
    class << stream
      attr_accessor :config, :domain, :user
    end
    stream.config = config
    stream.user = alice
    stream.domain = 'wonderland.lit'
  end

  describe 'when private storage feature is disabled' do
    let(:xml) do
      query = %q{<query xmlns="jabber:iq:private"><one xmlns="a"/></query>}
      node(%Q{<iq id="42" type="get">#{query}</iq>})
    end

    before do
      config.vhost('wonderland.lit').private_storage false
    end

    it 'raises a service-unavailable stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::ServiceUnavailable
      stream.verify
    end
  end

  describe 'when retrieving a fragment for another user jid' do
    let(:xml) do
      query = %q{<query xmlns="jabber:iq:private"><one xmlns="a"/></query>}
      node(%Q{<iq id="42" to="hatter@wonderland.lit" type="get">#{query}</iq>})
    end

    it 'raises a forbidden stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::Forbidden
      stream.verify
    end
  end

  describe 'when get stanza contains zero child elements' do
    let(:xml) do
      query = %q{<query xmlns="jabber:iq:private"></query>}
      node(%Q{<iq id="42" type="get">#{query}</iq>})
    end

    it 'raises a not-acceptable stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::NotAcceptable
      stream.verify
    end
  end

  describe 'when get stanza contains more than one child element' do
    let(:xml) do
      query = %q{<query xmlns="jabber:iq:private"><one xmlns="a"/><two xmlns="b"/></query>}
      node(%Q{<iq id="42" type="get">#{query}</iq>})
    end

    it 'raises a not-acceptable stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::NotAcceptable
      stream.verify
    end
  end

  describe 'when get stanza is missing a namespace' do
    let(:xml) do
      query = %q{<query xmlns="jabber:iq:private"><one/></query>}
      node = node(%Q{<iq id="42" type="get">#{query}</iq>})
    end

    it 'raises a not-acceptable stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::NotAcceptable
      stream.verify
    end
  end

  describe 'when get stanza is missing fragment' do
    let(:xml) do
      query = %q{<query xmlns="jabber:iq:private"><one xmlns="a"/></query>}
      node(%Q{<iq id="42" type="get">#{query}</iq>})
    end

    before do
      storage.expect :find_fragment, nil, [alice.jid, xml.elements[0].elements[0]]
      stream.expect :storage, storage, ['wonderland.lit']
    end

    it 'raises an item-not-found stanza error' do
      -> { subject.process }.must_raise Vines::StanzaErrors::ItemNotFound
      stream.verify
      storage.verify
    end
  end

  describe 'when get finds fragment successfully' do
    let(:xml) do
      query = %q{<query xmlns="jabber:iq:private"><one xmlns="a"/></query>}
      node = node(%Q{<iq id="42" type="get">#{query}</iq>})
    end

    before do
      data = %q{<one xmlns="a"><child>data</child></one>}
      query = %Q{<query xmlns="jabber:iq:private">#{data}</query>}
      expected = node(%Q{<iq from="#{alice.jid}" id="42" to="#{alice.jid}" type="result">#{query}</iq>})

      storage.expect :find_fragment, node(data), [alice.jid, xml.elements[0].elements[0]]
      stream.expect :storage, storage, ['wonderland.lit']
      stream.expect :write, nil, [expected]
    end

    it 'writes a response to the stream' do
      subject.process
      stream.verify
      storage.verify
    end
  end

  describe 'when saving a fragment' do
    let(:result) { node(%Q{<iq from="#{alice.jid}" id="42" to="#{alice.jid}" type="result"/>}) }

    before do
      storage.expect :save_fragment, nil, [alice.jid, xml.elements[0].elements[0]]
      stream.expect :storage, storage, ['wonderland.lit']
      stream.expect :write, nil, [result]
    end

    describe 'and stanza contains zero child elements' do
      let(:xml) do
        query = %q{<query xmlns="jabber:iq:private"></query>}
        node(%Q{<iq id="42" type="set">#{query}</iq>})
      end

      it 'raises a not-acceptable stanza error' do
        -> { subject.process }.must_raise Vines::StanzaErrors::NotAcceptable
      end
    end

    describe 'and a single single fragment saves successfully' do
      let(:xml) do
        query = %q{<query xmlns="jabber:iq:private"><one xmlns="a"/></query>}
        node(%Q{<iq id="42" type="set">#{query}</iq>})
      end

      it 'writes a result to the stream' do
        subject.process
        stream.verify
        storage.verify
      end
    end

    describe 'and two fragments save successfully' do
      let(:xml) do
        query = %q{<query xmlns="jabber:iq:private"><one xmlns="a"/><two xmlns="a"/></query>}
        node(%Q{<iq id="42" type="set">#{query}</iq>})
      end

      before do
        storage.expect :save_fragment, nil, [alice.jid, xml.elements[0].elements[1]]
        stream.expect :storage, storage, ['wonderland.lit']
      end

      it 'writes a result to the stream' do
        subject.process
        stream.verify
        storage.verify
      end
    end
  end
end
