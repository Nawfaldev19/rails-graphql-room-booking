module Mutations
  class BaseMutation < GraphQL::Schema::Mutation
    include Guards

    null false
  end
end
