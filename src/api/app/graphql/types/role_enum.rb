module Types
  class RoleEnum < GraphQL::Schema::Enum
    Membership::ROLES.each { |role| value role.upcase, value: role }
  end
end
