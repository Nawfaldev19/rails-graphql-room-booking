module Types
  class PreferencesType < BaseObject
    description "What the holder of an unsubscribe link may see and change."

    field :workspace_name, String, null: false
    field :person_name, String, null: false
    field :preferences, [ PreferenceType ], null: false
  end
end
