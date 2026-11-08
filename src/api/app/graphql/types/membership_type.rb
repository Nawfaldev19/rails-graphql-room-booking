module Types
  class MembershipType < BaseObject
    description "A person's place in one workspace."

    field :id, ID, null: false
    field :role, RoleEnum, null: false
    field :name, String, null: false
    field :instrument, String
    field :phone, String
    field :missing_profile_details, [ String ],
          null: false, description: "Details still needed before a first booking. Empty when complete."
    field :workspace, WorkspaceSummaryType, null: false

    def name = object.user.name
  end
end
