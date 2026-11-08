class NotificationTemplate < ApplicationRecord
  include TenantScoped

  KINDS = %w[confirmation change cancellation].freeze

  validates :kind, inclusion: { in: KINDS }, uniqueness: { scope: :workspace_id }
  validates :subject, presence: true, length: { maximum: 150 }
  validates :body, presence: true, length: { maximum: 4000 }
  validate :merge_tags_are_known

  private

  def merge_tags_are_known
    Notifications::TemplateRenderer.problems(subject.to_s).each { |problem| errors.add(:subject, problem) }
    Notifications::TemplateRenderer.problems(body.to_s).each { |problem| errors.add(:body, problem) }
  end
end
