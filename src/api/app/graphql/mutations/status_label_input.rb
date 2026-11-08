module Mutations
  class StatusLabelInput < GraphQL::Schema::InputObject
    argument :status, Types::BookingStatusEnum
    argument :label, String, description: "Leave empty to use the default word."
  end
end
