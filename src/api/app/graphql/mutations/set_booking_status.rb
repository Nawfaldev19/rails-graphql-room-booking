module Mutations
  class SetBookingStatus < BaseMutation
    description "Staff only. Marks a booking as checked in or missed."

    argument :booking_id, ID
    argument :status, Types::BookingStatusEnum
    type Types::BookingType

    def resolve(**arguments)
      Bookings::Actions.new(staff!, now:).set_status(**arguments)
    end
  end
end
