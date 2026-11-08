module Types
  class DeliveryStatusEnum < GraphQL::Schema::Enum
    Delivery::STATUSES.each { |status| value status.upcase, value: status }
  end
end
