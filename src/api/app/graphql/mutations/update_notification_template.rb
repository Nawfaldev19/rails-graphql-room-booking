module Mutations
  class UpdateNotificationTemplate < BaseMutation
    description "Admins only. A template with an unknown merge tag is refused."

    argument :kind, Types::NotificationKindEnum
    argument :subject, String
    argument :body, String
    type Types::TemplateType

    def resolve(kind:, subject:, body:)
      admin!
      template = NotificationTemplate.find_or_initialize_by(kind:)
      template.update!(subject: subject.strip, body: body.strip)
      { kind:, subject: template.subject, body: template.body, is_default: false }
    end
  end
end
