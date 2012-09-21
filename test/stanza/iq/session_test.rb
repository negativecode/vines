# encoding: UTF-8

require 'test_helper'

describe Vines::Stanza::Iq::Session do
  subject      { Vines::Stanza::Iq::Session.new(xml, stream) }
  let(:stream) { MiniTest::Mock.new }
  let(:alice)  { Vines::User.new(jid: 'alice@wonderland.lit/tea') }

  describe 'when session initiation is requested' do
    let(:xml) { node(%q{<iq id="42" type="set"><session xmlns="urn:ietf:params:xml:ns:xmpp-session"/></iq>}) }
    let(:result) { node(%q{<iq from="wonderland.lit" id="42" to="alice@wonderland.lit/tea" type="result"/>}) }

    before do
      stream.expect :domain, 'wonderland.lit'
      stream.expect :user, alice
      stream.expect :write, nil, [result]
    end

    it 'just returns a result to satisy older clients' do
      subject.process
      stream.verify
    end
  end
end
