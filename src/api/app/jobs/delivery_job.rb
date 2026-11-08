# Sends what is queued for one workspace. If the rate limit stops it part-way,
# it schedules itself again for when the next message is allowed.
class DeliveryJob < ApplicationJob
  queue_as :default

  def perform(workspace_id)
    workspace = Workspace.find_by(id: workspace_id)
    return if workspace.nil?

    result = Tenancy.with(workspace) { Notifications::Outbox.drain }
    return if result.remaining.zero?

    self.class.set(wait: result.retry_in.clamp(1, 60).seconds).perform_later(workspace_id)
  end
end
