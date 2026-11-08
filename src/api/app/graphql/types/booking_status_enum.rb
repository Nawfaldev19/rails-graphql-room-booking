module Types
  class BookingStatusEnum < GraphQL::Schema::Enum
    Booking::STATUSES.each { |status| value status.upcase, value: status }
  end
end
