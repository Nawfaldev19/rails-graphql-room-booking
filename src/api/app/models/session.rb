# A signed-in browser. The cookie holds a random token; only its SHA-256 digest
# is stored, so a copy of the database cannot be used to sign in.
class Session < ApplicationRecord
  COOKIE = :room_booking_session

  belongs_to :user

  scope :active, ->(now = Time.current) { where("expires_at > ?", now) }

  def self.digest(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  def self.start(user, ttl: Rails.configuration.x.session_ttl)
    token = SecureRandom.urlsafe_base64(32)
    session = create!(user:, token_digest: digest(token), expires_at: Time.current + ttl)
    [ token, session ]
  end

  def self.find_user(token)
    return nil if token.blank?

    active.find_by(token_digest: digest(token))&.user
  end
end
