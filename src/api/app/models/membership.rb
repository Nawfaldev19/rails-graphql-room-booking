# A user's place in one workspace. It is the bridge between the directory (users)
# and tenant data, so it is not tenant-scoped itself: it is always reached
# through a user or through the current workspace.
class Membership < ApplicationRecord
  ROLES = %w[admin staff student].freeze

  belongs_to :workspace
  belongs_to :user

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :workspace_id }
  validates :instrument, length: { maximum: 60 }
  validates :phone, length: { maximum: 30 },
                    format: { with: /\A[0-9 +()-]*\z/, message: "may only contain digits, spaces and + ( ) -" }

  ROLES.each do |name|
    define_method(:"#{name}?") { role == name }
  end

  # Staff and admins manage bookings for everyone.
  def manages_bookings?
    admin? || staff?
  end

  def missing_profile_details
    %w[instrument phone].select { |detail| self[detail].blank? }
  end
end
