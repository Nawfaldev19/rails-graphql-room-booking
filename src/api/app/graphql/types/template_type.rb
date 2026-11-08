module Types
  class TemplateType < BaseObject
    field :kind, NotificationKindEnum, null: false
    field :subject, String, null: false
    field :body, String, null: false
    field :is_default, Boolean, null: false
  end
end
