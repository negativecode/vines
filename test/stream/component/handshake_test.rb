# encoding: UTF-8

require 'test_helper'

describe Vines::Stream::Component::Handshake do
  subject      { Vines::Stream::Component::Handshake.new(stream) }
  let(:stream) { MiniTest::Mock.new }

  describe 'when invalid element is received' do
    it 'raises a not-authorized stream error' do
      node = node('<message/>')
       -> { subject.node(node) }.must_raise Vines::StreamErrors::NotAuthorized
    end
  end

  describe 'when handshake with no text is received' do
    it 'raises a not-authorized stream error' do
      stream.expect :secret, 'secr3t'
      node = node('<handshake/>')
      -> { subject.node(node) }.must_raise Vines::StreamErrors::NotAuthorized
      stream.verify
    end
  end

  describe 'when handshake with invalid secret is received' do
    it 'raises a not-authorized stream error' do
      stream.expect :secret, 'secr3t'
      node = node('<handshake>bogus</handshake>')
      -> { subject.node(node) }.must_raise Vines::StreamErrors::NotAuthorized
      stream.verify
    end
  end

  describe 'when good handshake is received' do
    let(:router) { MiniTest::Mock.new }

    before do
      router.expect :<<, nil, [stream]
      stream.expect :router, router
      stream.expect :secret, 'secr3t'
      stream.expect :write, nil, ['<handshake/>']
      stream.expect :advance, nil, [Vines::Stream::Component::Ready.new(stream)]
    end

    it 'completes the handshake and advances the stream into the ready state' do
      node = node('<handshake>secr3t</handshake>')
      subject.node(node)
      stream.verify
      router.verify
    end
  end
end
