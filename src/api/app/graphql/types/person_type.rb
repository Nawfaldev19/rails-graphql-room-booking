module Types
  class PersonType < BaseObject
    description "Someone staff can make a booking for."

    field :id, ID, null: false
    field :name, String, null: false
    field :role, RoleEnum, null: false

    def name = object.user.name
  end
end
