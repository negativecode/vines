# encoding: UTF-8

require 'test_helper'

describe Vines::TokenBucket do
  subject { Vines::TokenBucket.new(10, 1) }

  it 'raises with invalid capacity and rate values' do
    -> { Vines::TokenBucket.new(0, 1) }.must_raise ArgumentError
    -> { Vines::TokenBucket.new(1, 0) }.must_raise ArgumentError
    -> { Vines::TokenBucket.new(-1, 1) }.must_raise ArgumentError
    -> { Vines::TokenBucket.new(1, -1) }.must_raise ArgumentError
  end

  it 'does not allow taking a negative number of tokens' do
    -> { subject.take(-1) }.must_raise ArgumentError
  end

  it 'does not allow taking more tokens than its capacity' do
    refute subject.take(11)
  end

  it 'allows taking all tokens, but no more' do
    assert subject.take(10)
    refute subject.take(1)
  end

  it 'refills over time' do
    assert subject.take(10)
    refute subject.take(1)
    sleep(1)
    assert subject.take(1)
    refute subject.take(1)
  end
end
