module Mutations
  class Login < BaseMutation
    argument :email, String
    argument :password, String
    type Types::ViewerType

    def resolve(email:, password:)
      user, token, expires_at = Auth::SignIn.call(email:, password:, client_key: context[:client_key])
      context[:cookies][Session::COOKIE] = {
        value: token, expires: expires_at, httponly: true, same_site: :lax, secure: context[:secure]
      }
      user
    end
  end
end
