class Room < ApplicationRecord
  include TenantScoped

  has_many :bookings, dependent: :restrict_with_exception

  validates :name, presence: true, length: { maximum: 60 }, uniqueness: { scope: :workspace_id }
  validates :capacity, numericality: { only_integer: true, in: 1..200 }
  validates :opens_minute, :closes_minute, numericality: { only_integer: true, in: 0..1440 }
  validate :opens_before_closing

  scope :in_order, -> { order(:name) }

  private

  def opens_before_closing
    return if opens_minute.blank? || closes_minute.blank? || opens_minute < closes_minute

    errors.add(:closes_minute, "must be after the opening time")
  end
end
