class Workspace < ApplicationRecord
  # The statuses a booking can have. Their meaning is fixed; only the words shown
  # to people can be changed per workspace.
  DEFAULT_STATUS_LABELS = {
    "booked" => "Booked",
    "checked_in" => "Checked in",
    "cancelled" => "Cancelled",
    "missed" => "Missed"
  }.freeze
  LABEL_LENGTH = 24

  has_many :memberships, dependent: :restrict_with_exception
  has_many :users, through: :memberships

  validates :name, presence: true, length: { maximum: 80 }
  validates :weekly_limit_minutes, numericality: { only_integer: true, in: 30..(7 * 24 * 60) }
  validate :time_zone_exists
  validate :status_labels_are_renames_only

  def zone
    ActiveSupport::TimeZone[time_zone]
  end

  # The label for a status: the workspace's own word, or the default.
  def status_label(status)
    status_labels[status.to_s].presence || DEFAULT_STATUS_LABELS.fetch(status.to_s)
  end

  def all_status_labels
    DEFAULT_STATUS_LABELS.keys.index_with { |status| status_label(status) }
  end

  private

  def time_zone_exists
    errors.add(:time_zone, "is not a known time zone") if zone.nil?
  end

  def status_labels_are_renames_only
    unless status_labels.is_a?(Hash)
      errors.add(:status_labels, "must be a set of status and label pairs")
      return
    end

    unknown = status_labels.keys.map(&:to_s) - DEFAULT_STATUS_LABELS.keys
    errors.add(:status_labels, "cannot add the status #{unknown.join(', ')}") if unknown.any?
    too_long_labels.each do |status|
      errors.add(:status_labels, "for #{status} is too long (#{LABEL_LENGTH} characters at most)")
    end

    shown = all_status_labels.values.map { |label| label.strip.downcase }
    errors.add(:status_labels, "must be different from each other") if shown.uniq.size != shown.size
  end

  def too_long_labels
    status_labels.select { |_status, label| label.to_s.strip.length > LABEL_LENGTH }.keys
  end
end
