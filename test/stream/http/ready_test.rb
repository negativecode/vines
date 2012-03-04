# encoding: UTF-8

require 'tmpdir'
require 'vines'
require 'minitest/autorun'

describe Vines::Stream::Http::Ready do
  before do
    @stream = MiniTest::Mock.new
    @state = Vines::Stream::Http::Ready.new(@stream, nil)
  end

  it "raises when body element is missing" do
    node = node('<presence type="unavailable"/>')
    @stream.expect(:valid_session?, true, [nil])
    -> { @state.node(node) }.must_raise Vines::StreamErrors::NotAuthorized
  end

  it "raises when namespace is missing" do
    node = node('<body rid="42" sid="12"/>')
    @stream.expect(:valid_session?, true, ['12'])
    assert_raises(Vines::StreamErrors::NotAuthorized) { @state.node(node) }
    -> { @state.node(node) }.must_raise Vines::StreamErrors::NotAuthorized
  end

  it "raises when rid attribute is missing" do
    node = node('<body xmlns="http://jabber.org/protocol/httpbind" sid="12"/>')
    @stream.expect(:valid_session?, true, ['12'])
    -> { @state.node(node) }.must_raise Vines::StreamErrors::NotAuthorized
  end

  it "raises when session id is invalid" do
    @stream.expect(:valid_session?, false, ['12'])
    node = node('<body xmlns="http://jabber.org/protocol/httpbind" rid="42" sid="12"/>')
    -> { @state.node(node) }.must_raise Vines::StreamErrors::NotAuthorized
    assert @stream.verify
  end

  it "processes when body element is empty" do
    node = node('<body xmlns="http://jabber.org/protocol/httpbind" rid="42" sid="12"/>')
    @stream.expect(:valid_session?, true, ['12'])
    @stream.expect(:parse_body, [], [node])
    @state.node(node)
    assert @stream.verify
  end

  it "processes all stanzas in one body element" do
    alice = Vines::User.new(jid: 'alice@wonderland.lit')
    hatter = Vines::User.new(jid: 'hatter@wonderland.lit')

    config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
      end
    end

    bogus = node('<message type="bogus">raises stanza error</message>')
    ok = node('<message to="hatter@wonderland.lit">but processes this message</message>')
    node = node(%Q{<body xmlns="http://jabber.org/protocol/httpbind" rid="42" sid="12">#{bogus}#{ok}</body>})

    raises = Vines::Stanza.from_node(bogus, @stream)
    processes = Vines::Stanza.from_node(ok, @stream)

    recipient = MiniTest::Mock.new
    recipient.expect(:user, hatter)
    recipient.expect(:write, nil, [Vines::Stanza::Message])

    @stream.expect(:valid_session?, true, ['12'])
    @stream.expect(:parse_body, [raises, processes], [node])
    @stream.expect(:error, nil, [Vines::StanzaErrors::BadRequest])
    @stream.expect(:config, config)
    @stream.expect(:user, alice)
    @stream.expect(:connected_resources, [recipient], [hatter.jid])

    @state.node(node)
    assert @stream.verify
    assert recipient.verify
  end

  it "terminates the session" do
    node = node('<body xmlns="http://jabber.org/protocol/httpbind" rid="42" sid="12" type="terminate"/>')
    @stream.expect(:valid_session?, true, ['12'])
    @stream.expect(:parse_body, [], [node])
    @stream.expect(:terminate, nil)
    @state.node(node)
    assert @stream.verify
  end

  private

  def node(xml)
    Nokogiri::XML(xml).root
  end
end
