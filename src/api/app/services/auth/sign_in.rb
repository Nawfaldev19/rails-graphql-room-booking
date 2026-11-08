module Auth
  # Checks an email and password and starts a session.
  class SignIn
    ATTEMPTS = RateLimiting::TokenBucket.new(
      store: RateLimiting::MemoryStore.new, capacity: 8, refill_per_second: 8.0 / 60
    )
    # Compared against when the email is unknown, so that "no such user" takes as
    # long as "wrong password" and the two cannot be told apart by timing.
    DECOY = BCrypt::Password.create(SecureRandom.hex(16), cost: BCrypt::Engine.cost)

    def self.call(email:, password:, client_key:, attempts: ATTEMPTS)
      email = email.to_s.strip.downcase
      unless attempts.take("#{client_key}|#{email}")
        raise ApiError.new("RATE_LIMITED", "Too many sign-in attempts. Wait a minute and try again.")
      end

      user = User.find_by(email:)
      matches = if user
                  user.authenticate(password.to_s)
                else
                  DECOY.is_password?(password.to_s)
                  false
                end
      raise ApiError.unauthenticated("Email or password is wrong.") unless user && matches

      token, session = Session.start(user)
      [ user, token, session.expires_at ]
    end
  end
end
