class User < ApplicationRecord
  has_secure_password
  has_many :memberships, dependent: :restrict_with_exception
  has_many :sessions, dependent: :delete_all

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, uniqueness: true, length: { maximum: 200 },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, length: { maximum: 80 }
end
