module RateLimiting
  # A token bucket: it holds up to `capacity` tokens and gains `refill_per_second`
  # tokens each second. An action is allowed when it can take a token. This lets
  # short bursts through while holding the long-run rate to the refill rate.
  #
  # Where the bucket state lives is the store's business. MemoryStore is for one
  # process; RecordStore keeps it in the database so that every process shares it
  # and a restart does not reset it.
  class TokenBucket
    State = Struct.new(:tokens, :refilled_at)

    def initialize(store:, capacity:, refill_per_second:, clock: -> { Time.current })
      raise ArgumentError, "capacity must be positive" unless capacity.positive?
      raise ArgumentError, "refill_per_second must not be negative" if refill_per_second.negative?

      @store = store
      @capacity = capacity.to_f
      @refill_per_second = refill_per_second.to_f
      @clock = clock
    end

    # Takes `cost` tokens if they are there. Returns whether the action may go ahead.
    def take(key, cost: 1)
      now = @clock.call
      allowed = false
      @store.update(key) do |state|
        tokens = refill(state, now)
        allowed = tokens >= cost
        State.new(allowed ? tokens - cost : tokens, now)
      end
      allowed
    end

    # Seconds until `cost` tokens will be available, for scheduling a retry.
    def wait_time(key, cost: 1)
      tokens = refill(@store.read(key), @clock.call)
      return 0.0 if tokens >= cost
      return Float::INFINITY if @refill_per_second.zero?

      (cost - tokens) / @refill_per_second
    end

    private

    def refill(state, now)
      return @capacity if state.nil?

      elapsed = [ now - state.refilled_at, 0 ].max
      [ state.tokens + (elapsed * @refill_per_second), @capacity ].min
    end
  end
end
