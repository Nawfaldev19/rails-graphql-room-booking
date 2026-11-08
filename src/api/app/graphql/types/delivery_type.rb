module Types
  class DeliveryType < BaseObject
    field :id, ID, null: false
    field :kind, NotificationKindEnum, null: false
    field :to_email, String, null: false
    field :subject, String, null: false
    field :body, String, null: false
    field :calendar_file, String
    field :status, DeliveryStatusEnum, null: false
    field :skip_reason, String
    field :attempts, Integer, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :sent_at, GraphQL::Types::ISO8601DateTime
  end
end
