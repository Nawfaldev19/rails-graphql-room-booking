module Types
  class StatusLabelType < BaseObject
    field :status, BookingStatusEnum, null: false
    field :label, String, null: false
    field :default_label, String, null: false
  end
end
