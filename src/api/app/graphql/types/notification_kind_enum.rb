module Types
  class NotificationKindEnum < GraphQL::Schema::Enum
    NotificationTemplate::KINDS.each { |kind| value kind.upcase, value: kind }
  end
end
