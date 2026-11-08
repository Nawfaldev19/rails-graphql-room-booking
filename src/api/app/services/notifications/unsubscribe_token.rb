module Notifications
  # The link at the foot of every message. It carries a signed membership id, so
  # it works without signing in, cannot be forged for someone else, and never
  # expires (a link in an old email must still work).
  module UnsubscribeToken
    PURPOSE = :notification_preferences

    module_function

    def for(membership)
      verifier.generate(membership.id, purpose: PURPOSE)
    end

    def url_for(membership)
      "#{Rails.configuration.x.public_url}/preferences/#{self.for(membership)}"
    end

    # The membership the token was made for, or nil if it is not a valid token.
    def membership(token)
      id = verifier.verified(token.to_s, purpose: PURPOSE)
      id && Membership.find_by(id:)
    end

    def verifier
      Rails.application.message_verifier("unsubscribe")
    end
  end
end
