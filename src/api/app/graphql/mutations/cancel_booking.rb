module Mutations
  class CancelBooking < BaseMutation
    argument :booking_id, ID
    argument :reason, String, required: false
    argument :notify, Boolean, required: false, default_value: true
    type Types::BookingType

    def resolve(**arguments)
      Bookings::Actions.new(actor!, now:).cancel(**arguments)
    end
  end
end
