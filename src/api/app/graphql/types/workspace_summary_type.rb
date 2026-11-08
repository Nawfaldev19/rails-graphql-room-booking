module Types
  class WorkspaceSummaryType < BaseObject
    field :id, ID, null: false
    field :name, String, null: false
    field :time_zone, String, null: false
  end
end
