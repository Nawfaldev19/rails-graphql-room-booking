module Mutations
  class Logout < BaseMutation
    type Boolean

    def resolve
      token = context[:cookies][Session::COOKIE]
      Session.where(token_digest: Session.digest(token)).delete_all if token.present?
      context[:cookies].delete(Session::COOKIE)
      true
    end
  end
end
