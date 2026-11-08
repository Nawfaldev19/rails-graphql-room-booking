module Mutations
  class CreateBooking < BaseMutation
    argument :room_id, ID
    argument :starts_at, GraphQL::Types::ISO8601DateTime
    argument :ends_at, GraphQL::Types::ISO8601DateTime
    argument :membership_id, ID, required: false, description: "Staff only: who the booking is for."
    argument :note, String, required: false
    argument :notify, Boolean, required: false, default_value: true,
                               description: "Staff only: whether to tell the person."
    type Types::BookingType

    def resolve(**arguments)
      Bookings::Actions.new(actor!, now:).create(**arguments)
    end
  end
end
