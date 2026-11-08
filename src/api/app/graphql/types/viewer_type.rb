module Types
  class ViewerType < BaseObject
    description "The signed-in user."

    field :id, ID, null: false
    field :name, String, null: false
    field :email, String, null: false
    field :memberships, [ MembershipType ], null: false

    def memberships
      object.memberships.includes(:workspace, :user).sort_by { |membership| membership.workspace.name }
    end
  end
end
