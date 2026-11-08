class Booking < ApplicationRecord
  include TenantScoped

  STATUSES = %w[booked checked_in cancelled missed].freeze
  # Statuses that hold the room. Only these can collide with another booking.
  ACTIVE_STATUSES = %w[booked checked_in].freeze

  belongs_to :room
  belongs_to :membership
  belongs_to :created_by, class_name: "Membership"

  validates :status, inclusion: { in: STATUSES }
  validates :starts_at, :ends_at, presence: true
  validates :note, length: { maximum: 200 }
  validates :cancel_reason, length: { maximum: 200 }
  validate :ends_after_start

  scope :active, -> { where(status: ACTIVE_STATUSES) }
  scope :overlapping, ->(from, to) { where("starts_at < ? AND ends_at > ?", to, from) }
  scope :chronological, -> { order(:starts_at, :id) }

  def active?
    ACTIVE_STATUSES.include?(status)
  end

  def minutes
    ((ends_at - starts_at) / 60).round
  end

  private

  def ends_after_start
    return if starts_at.blank? || ends_at.blank? || ends_at > starts_at

    errors.add(:ends_at, "must be after the start")
  end
end
