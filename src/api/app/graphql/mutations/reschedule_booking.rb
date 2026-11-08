module Mutations
  class RescheduleBooking < BaseMutation
    argument :booking_id, ID
    argument :room_id, ID
    argument :starts_at, GraphQL::Types::ISO8601DateTime
    argument :ends_at, GraphQL::Types::ISO8601DateTime
    argument :lock_version, Integer, description: "The version the edit started from. A mismatch is a CONFLICT."
    argument :notify, Boolean, required: false, default_value: true
    type Types::BookingType

    def resolve(**arguments)
      Bookings::Actions.new(actor!, now:).reschedule(**arguments)
    end
  end
end
