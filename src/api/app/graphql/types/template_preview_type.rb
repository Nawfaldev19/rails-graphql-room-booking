module Types
  class TemplatePreviewType < BaseObject
    field :subject, String, null: false
    field :body, String, null: false
    field :problems, [ String ], null: false
  end
end
