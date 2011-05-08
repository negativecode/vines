# encoding: UTF-8

module Vines

  # The token bucket algorithm is useful for rate limiting.
  # Before an operation can be completed, a token is taken from
  # the bucket.  If no tokens are available, the operation fails.
  # The bucket is refilled with tokens at the maximum allowed rate
  # of operations.
  class TokenBucket

    # Create a full bucket with capacity number of tokens to be filled
    # at the given rate of tokens/second.
    def initialize(capacity, rate)
      raise ArgumentError.new('capacity must be > 0') unless capacity > 0
      raise ArgumentError.new('rate must be > 0') unless rate > 0
      @capacity = capacity
      @tokens = capacity
      @rate = rate
      @timestamp = Time.new
    end

    # Returns true if tokens can be taken from the bucket.
    def take(tokens)
      raise ArgumentError.new('tokens must be > 0') unless tokens > 0
      if tokens <= fill
        @tokens -= tokens
        true
      else
        false
      end
    end

    private

    def fill
      if @tokens < @capacity
        now = Time.new
        delta = (@rate * (now - @timestamp)).round
        @tokens = [@capacity, @tokens + delta].min
        @timestamp = now
      end
      @tokens
    end
  end
end
