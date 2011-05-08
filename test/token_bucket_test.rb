# encoding: UTF-8

require 'vines'
require 'test/unit'

class TokenBucketTest < Test::Unit::TestCase
  def test_init
    assert_raises(ArgumentError) { Vines::TokenBucket.new(0, 1) }
    assert_raises(ArgumentError) { Vines::TokenBucket.new(1, 0) }
    assert_raises(ArgumentError) { Vines::TokenBucket.new(-1, 1) }
    assert_raises(ArgumentError) { Vines::TokenBucket.new(1, -1) }
  end

  def test_take
    bucket = Vines::TokenBucket.new(10, 1)
    assert_raises(ArgumentError) { bucket.take(-1) }
    assert(!bucket.take(11))
    assert(bucket.take(10))
    assert(!bucket.take(1))
    sleep(1)
    assert(bucket.take(1))
    assert(!bucket.take(1))
  end
end
