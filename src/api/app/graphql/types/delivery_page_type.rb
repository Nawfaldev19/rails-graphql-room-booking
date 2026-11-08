module Types
  class DeliveryPageType < BaseObject
    field :items, [ DeliveryType ], null: false
    field :end_cursor, String
    field :has_next_page, Boolean, null: false
  end
end
