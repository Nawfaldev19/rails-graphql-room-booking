module Mutations
  class SendQueuedMail < BaseMutation
    description "Staff only. Sends what the rate limit allows right now."

    type Types::OutboxResultType

    def resolve
      staff!
      result = Notifications::Outbox.drain(now:)
      { sent: result.sent, remaining: result.remaining }
    end
  end
end
