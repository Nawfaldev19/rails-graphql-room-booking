module Mutations
  class PreferenceInput < GraphQL::Schema::InputObject
    argument :kind, Types::NotificationKindEnum
    argument :enabled, Boolean
  end
end
