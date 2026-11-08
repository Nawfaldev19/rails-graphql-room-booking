# One row per person and kind of message, created only when someone changes the
# default. No row means "send".
class NotificationPreference < ApplicationRecord
  include TenantScoped

  belongs_to :membership

  validates :kind, inclusion: { in: NotificationTemplate::KINDS },
                   uniqueness: { scope: :membership_id }

  def self.enabled?(membership, kind)
    where(membership:, kind:).pick(:enabled) != false
  end
end
