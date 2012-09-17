# encoding: UTF-8

require 'test_helper'

describe Vines::Stanza::Iq::DiscoItems do
  subject      { Vines::Stanza::Iq::DiscoItems.new(xml, stream) }
  let(:stream) { MiniTest::Mock.new }
  let(:alice)  { Vines::User.new(jid: 'alice@wonderland.lit/home') }
  let(:config) do
    Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
        components 'tea' => 'secr3t', 'cake' => 'passw0rd'
      end
    end
  end

  before do
    class << stream
      attr_accessor :config, :user
    end
    stream.config = config
    stream.user = alice
  end

  describe 'when querying server items' do
    let(:xml) do
      query = %q{<query xmlns="http://jabber.org/protocol/disco#items"/>}
      node(%Q{<iq id="42" to="wonderland.lit" type="get">#{query}</iq>})
    end

    let(:result) do
      node(%q{
        <iq from="wonderland.lit" id="42" to="alice@wonderland.lit/home" type="result">
          <query xmlns="http://jabber.org/protocol/disco#items">
            <item jid="cake.wonderland.lit"/>
            <item jid="tea.wonderland.lit"/>
          </query>
        </iq>
      })
    end

    it 'includes component domains in output' do
      stream.expect :write, nil, [result]
      subject.process
      stream.verify
    end
  end
end
