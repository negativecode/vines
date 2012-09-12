# encoding: UTF-8

require 'test_helper'

describe Vines::Stanza::Iq::Version do
  subject      { Vines::Stanza::Iq::Version.new(xml, stream) }
  let(:alice)  { Vines::User.new(jid: 'alice@wonderland.lit/tea') }
  let(:stream) { MiniTest::Mock.new }
  let(:config) do
    Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
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

  describe 'when not addressed to the server' do
    let(:router) { MiniTest::Mock.new }
    let(:xml) { node(%q{<iq id="42" to="romeo@verona.lit" type="get"><query xmlns="jabber:iq:version"/></iq>}) }

    before do
      router.expect :route, nil, [xml]
      stream.expect :router, router
    end

    it 'routes the stanza to the recipient jid' do
      subject.process
      stream.verify
      router.verify
    end
  end

  describe 'when missing a to address' do
    let(:xml) { node(%q{<iq id="42" type="get"><query xmlns="jabber:iq:version"/></iq>}) }
    let(:expected) do
      node(%Q{
        <iq from="wonderland.lit" id="42" to="alice@wonderland.lit/tea" type="result">
          <query xmlns="jabber:iq:version">
            <name>Vines</name>
            <version>#{Vines::VERSION}</version>
          </query>
        </iq>})
    end

    before do
      stream.expect :domain, 'wonderland.lit'
      stream.expect :domain, 'wonderland.lit'
      stream.expect :write, nil, [expected]
    end

    it 'returns a version result when missing a to jid' do
      subject.process
      stream.verify
    end
  end
end
