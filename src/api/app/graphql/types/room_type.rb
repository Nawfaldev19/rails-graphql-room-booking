module Types
  class RoomType < BaseObject
    field :id, ID, null: false
    field :name, String, null: false
    field :capacity, Integer, null: false
    field :opens_minute, Integer, null: false, description: "Minutes after local midnight."
    field :closes_minute, Integer, null: false
    field :equipment, [ String ], null: false
  end
end
