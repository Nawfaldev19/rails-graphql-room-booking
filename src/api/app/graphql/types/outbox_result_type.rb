module Types
  class OutboxResultType < BaseObject
    field :sent, Integer, null: false
    field :remaining, Integer, null: false
  end
end
