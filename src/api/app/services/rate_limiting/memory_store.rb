module RateLimiting
  # Bucket state in this process only. Used for sign-in attempts, where losing
  # the counters on restart is acceptable.
  class MemoryStore
    def initialize(max_keys: 10_000)
      @states = {}
      @max_keys = max_keys
      @mutex = Mutex.new
    end

    def read(key)
      @mutex.synchronize { @states[key] }
    end

    def update(key)
      @mutex.synchronize do
        @states.shift if @states.size >= @max_keys && !@states.key?(key)
        @states[key] = yield(@states[key])
      end
    end

    def clear
      @mutex.synchronize { @states.clear }
    end
  end
end
