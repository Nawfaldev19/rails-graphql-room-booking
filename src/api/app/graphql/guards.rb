# Access checks shared by types and mutations. Each returns what it checked, so
# a resolver can write `person = actor!`.
module Guards
  def current_user
    context[:user]
  end

  # The signed-in user's membership of the current workspace.
  def actor!
    raise ApiError.unauthenticated if context[:user].nil?

    context[:membership] || raise(Tenancy::NotSet)
  end

  def staff!
    actor!.tap { |actor| raise ApiError.forbidden unless actor.manages_bookings? }
  end

  def admin!
    actor!.tap { |actor| raise ApiError.forbidden unless actor.admin? }
  end

  def now
    context[:now]
  end
end
