# encoding: UTF-8

module Vines

  # The token bucket algorithm is useful for rate limiting.
  # Before an operation can be completed, a token is taken from
  # the bucket.  If no tokens are available, the operation fails.
  # The bucket is refilled with tokens at the maximum allowed rate
  # of operations.
  class TokenBucket

    # Create a full bucket with `capacity` number of tokens to be filled
    # at the given rate of tokens/second.
    #
    # capacity - The Fixnum maximum number of tokens the bucket can hold.
    # rate     - The Fixnum number of tokens per second at which the bucket is
    #            refilled.
    def initialize(capacity, rate)
      raise ArgumentError.new('capacity must be > 0') unless capacity > 0
      raise ArgumentError.new('rate must be > 0') unless rate > 0
      @capacity = capacity
      @tokens = capacity
      @rate = rate
      @timestamp = Time.new
    end

    # Remove tokens from the bucket if it's full enough. There's no way, or
    # need, to add tokens to the bucket. It refills over time.
    #
    # tokens - The Fixnum number of tokens to attempt to take from the bucket.
    #
    # Returns true if the bucket contains enough tokens to take, false if the
    # bucket isn't full enough to satisy the request.
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

    # Add tokens to the bucket at the `rate` provided in the constructor. This
    # fills the bucket slowly over time.
    #
    # Returns the Fixnum number of tokens left in the bucket.
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
