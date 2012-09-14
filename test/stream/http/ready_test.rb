# encoding: UTF-8

require 'test_helper'

describe Vines::Stream::Http::Ready do
  subject      { Vines::Stream::Http::Ready.new(stream, nil) }
  let(:stream) { MiniTest::Mock.new }
  let(:alice)  { Vines::User.new(jid: 'alice@wonderland.lit') }
  let(:hatter) { Vines::User.new(jid: 'hatter@wonderland.lit') }
  let(:config) do
    Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
      end
    end
  end

  it "raises when body element is missing" do
    node = node('<presence type="unavailable"/>')
    stream.expect :valid_session?, true, [nil]
    -> { subject.node(node) }.must_raise Vines::StreamErrors::NotAuthorized
  end

  it "raises when namespace is missing" do
    node = node('<body rid="42" sid="12"/>')
    stream.expect :valid_session?, true, ['12']
    -> { subject.node(node) }.must_raise Vines::StreamErrors::NotAuthorized
  end

  it "raises when rid attribute is missing" do
    node = node('<body xmlns="http://jabber.org/protocol/httpbind" sid="12"/>')
    stream.expect :valid_session?, true, ['12']
    -> { subject.node(node) }.must_raise Vines::StreamErrors::NotAuthorized
  end

  it "raises when session id is invalid" do
    stream.expect :valid_session?, false, ['12']
    node = node('<body xmlns="http://jabber.org/protocol/httpbind" rid="42" sid="12"/>')
    -> { subject.node(node) }.must_raise Vines::StreamErrors::NotAuthorized
    stream.verify
  end

  it "processes when body element is empty" do
    node = node('<body xmlns="http://jabber.org/protocol/httpbind" rid="42" sid="12"/>')
    stream.expect :valid_session?, true, ['12']
    stream.expect :parse_body, [], [node]
    subject.node(node)
    stream.verify
  end

  describe 'when receiving multiple stanzas in one body element' do
    let(:recipient) { MiniTest::Mock.new }
    let(:bogus) { node('<message type="bogus">raises stanza error</message>') }
    let(:ok) { node('<message to="hatter@wonderland.lit">but processes this message</message>') }
    let(:xml) { node(%Q{<body xmlns="http://jabber.org/protocol/httpbind" rid="42" sid="12">#{bogus}#{ok}</body>}) }
    let(:raises) { Vines::Stanza.from_node(bogus, stream) }
    let(:processes) { Vines::Stanza.from_node(ok, stream) }

    before do
      recipient.expect :user, hatter
      recipient.expect :write, nil, [Vines::Stanza::Message]

      stream.expect :valid_session?, true, ['12']
      stream.expect :parse_body, [raises, processes], [xml]
      stream.expect :error, nil, [Vines::StanzaErrors::BadRequest]
      stream.expect :config, config
      stream.expect :user, alice
      stream.expect :connected_resources, [recipient], [hatter.jid]
    end

    it 'processes all stanzas' do
      subject.node(xml)
      stream.verify
      recipient.verify
    end
  end

  it "terminates the session" do
    node = node('<body xmlns="http://jabber.org/protocol/httpbind" rid="42" sid="12" type="terminate"/>')
    stream.expect :valid_session?, true, ['12']
    stream.expect :parse_body, [], [node]
    stream.expect :terminate, nil
    subject.node(node)
    stream.verify
  end
end
