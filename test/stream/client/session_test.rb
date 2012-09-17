# encoding: UTF-8

require 'test_helper'

describe Vines::Stream::Client::Session do
  subject       { Vines::Stream::Client::Session.new(stream) }
  let(:another) { Vines::Stream::Client::Session.new(stream) }
  let(:stream)  { OpenStruct.new(config: nil) }

  describe 'session equality checks' do
    it 'uses class in equality check' do
      (subject <=> 42).must_be_nil
    end

    it 'is equal to itself' do
      assert subject == subject
      assert subject.eql?(subject)
      assert subject.hash == subject.hash
    end

    it 'is not equal to another session' do
      refute subject == another
      refute subject.eql?(another)
      refute subject.hash == another.hash
    end
  end
end
