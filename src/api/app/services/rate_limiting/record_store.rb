module RateLimiting
  # Bucket state in the database, one row per key. The read and the write happen
  # in one transaction, so two processes cannot both spend the last token.
  class RecordStore
    def read(key)
      row = RateBucket.find_by(key:)
      row && TokenBucket::State.new(row.tokens, row.refilled_at)
    end

    def update(key)
      RateBucket.transaction do
        row = RateBucket.find_by(key:)
        state = yield(row && TokenBucket::State.new(row.tokens, row.refilled_at))
        if row
          row.update!(tokens: state.tokens, refilled_at: state.refilled_at)
        else
          RateBucket.create!(key:, tokens: state.tokens, refilled_at: state.refilled_at)
        end
      end
    end
  end
end
