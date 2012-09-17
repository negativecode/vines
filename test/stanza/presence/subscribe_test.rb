# encoding: UTF-8

require 'test_helper'

describe Vines::Stanza::Presence::Subscribe do
  subject       { Vines::Stanza::Presence::Subscribe.new(xml, stream) }
  let(:stream)  { MiniTest::Mock.new }
  let(:alice)   { Vines::JID.new('alice@wonderland.lit/tea') }
  let(:hatter)  { Vines::JID.new('hatter@wonderland.lit') }
  let(:contact) { Vines::Contact.new(jid: hatter) }

  before do
    class << stream
      attr_accessor :user, :nodes
      def write(node)
        @nodes ||= []
        @nodes << node
      end
    end
  end

  describe 'outbound subscription to a local jid, but missing contact' do
    let(:xml) { node(%q{<presence id="42" to="hatter@wonderland.lit" type="subscribe"/>}) }
    let(:user) { MiniTest::Mock.new }
    let(:storage) { MiniTest::Mock.new }
    let(:recipient) { MiniTest::Mock.new }

    before do
      class << user
        attr_accessor :jid
      end
      user.jid = alice
      user.expect :request_subscription, nil, [hatter]
      user.expect :contact, contact, [hatter]

      storage.expect :save_user, nil, [user]
      storage.expect :find_user, nil, [hatter]

      recipient.expect :user, user
      class << recipient
        attr_accessor :nodes
        def write(node)
          @nodes ||= []
          @nodes << node
        end
      end

      stream.user = user
      stream.expect :domain, 'wonderland.lit'
      stream.expect :storage, storage, ['wonderland.lit']
      stream.expect :storage, storage, ['wonderland.lit']
      stream.expect :interested_resources, [recipient], [alice]
      stream.expect :update_user_streams, nil, [user]

      class << subject
        def route_iq; false; end
        def inbound?; false; end
        def local?;   true;  end
      end
    end

    it 'rejects the subscription with an unsubscribed response' do
      subject.process
      stream.verify
      user.verify
      storage.verify
      stream.nodes.size.must_equal 1

      expected = node(%q{<presence from="hatter@wonderland.lit" id="42" to="alice@wonderland.lit" type="unsubscribed"/>})
      stream.nodes.first.must_equal expected
    end

    it 'sends a roster set to the interested resources with subscription none' do
      subject.process
      recipient.nodes.size.must_equal 1

      query = %q{<query xmlns="jabber:iq:roster"><item jid="hatter@wonderland.lit" subscription="none"/></query>}
      expected = node(%Q{<iq to="alice@wonderland.lit/tea" type="set">#{query}</iq>})
      recipient.nodes.first.remove_attribute('id') # id is random
      recipient.nodes.first.must_equal expected
    end
  end
end
