# One message to one person: what was to be sent, and what became of it.
# In this demo nothing leaves the machine; "sent" rows are the outbox.
class Delivery < ApplicationRecord
  include TenantScoped

  STATUSES = %w[queued sent skipped].freeze

  belongs_to :membership
  belongs_to :booking, optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :kind, inclusion: { in: NotificationTemplate::KINDS }

  scope :queued, -> { where(status: "queued") }
  scope :newest_first, -> { order(created_at: :desc, id: :desc) }
end
