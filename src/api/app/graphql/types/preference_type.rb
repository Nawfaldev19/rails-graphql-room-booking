module Types
  class PreferenceType < BaseObject
    field :kind, NotificationKindEnum, null: false
    field :enabled, Boolean, null: false
  end
end
