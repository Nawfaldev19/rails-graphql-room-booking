module Types
  class BaseObject < GraphQL::Schema::Object
    include Guards
  end
end
