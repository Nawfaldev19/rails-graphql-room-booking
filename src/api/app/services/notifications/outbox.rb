module Notifications
  # Sends queued deliveries for the current workspace, oldest first, as fast as
  # the rate limit allows. What cannot go out now stays queued; nothing is dropped.
  class Outbox
    Result = Struct.new(:sent, :remaining, :retry_in)

    def self.limiter
      @limiter ||= RateLimiting::TokenBucket.new(
        store: RateLimiting::RecordStore.new,
        capacity: Rails.configuration.x.mail_burst,
        refill_per_second: Rails.configuration.x.mail_per_second
      )
    end

    def self.drain(limiter: self.limiter, now: Time.current)
      key = "mail:workspace:#{Tenancy.current!.id}"
      sent = 0
      Delivery.queued.order(:created_at, :id).each do |delivery|
        break unless limiter.take(key)

        deliver(delivery, now)
        sent += 1
      end
      remaining = Delivery.queued.count
      Result.new(sent, remaining, remaining.zero? ? nil : limiter.wait_time(key))
    end

    # This demo has no mail server. Marking the row as sent is the delivery; a
    # real adapter would hand the message to a mail service at this point.
    def self.deliver(delivery, now)
      delivery.update!(status: "sent", sent_at: now, attempts: delivery.attempts + 1)
    end
  end
end
