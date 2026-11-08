module Types
  class WorkspaceType < BaseObject
    description "The current workspace. Everything below it belongs to this workspace only."

    MAX_RANGE = 31.days

    field :id, ID, null: false
    field :name, String, null: false
    field :time_zone, String, null: false
    field :weekly_limit_minutes, Integer, null: false
    field :me, MembershipType, null: false
    field :status_labels, [ StatusLabelType ], null: false
    field :rooms, [ RoomType ], null: false
    field :people, [ PersonType ], null: false, description: "Staff only."
    field :bookings, [ BookingType ], null: false do
      argument :from, GraphQL::Types::ISO8601DateTime
      argument :to, GraphQL::Types::ISO8601DateTime
    end
    field :my_bookings, [ BookingType ], null: false,
                                         description: "The viewer's own bookings from the last week onward."
    field :notification_templates, [ TemplateType ], null: false, description: "Admins only."
    field :template_tags, [ TemplateTagType ], null: false
    field :template_preview, TemplatePreviewType, null: false do
      argument :subject, String
      argument :body, String
    end
    field :deliveries, DeliveryPageType, null: false, description: "Staff only." do
      argument :first, Integer, required: false, default_value: 20
      argument :after, String, required: false
    end
    field :queued_deliveries, Integer, null: false, description: "Staff only."

    def me = actor!

    def status_labels
      object.all_status_labels.map do |status, label|
        { status:, label:, default_label: Workspace::DEFAULT_STATUS_LABELS.fetch(status) }
      end
    end

    def rooms
      actor!
      Room.in_order
    end

    def people
      staff!
      object.memberships.includes(:user).sort_by { |membership| membership.user.name }
    end

    def bookings(from:, to:)
      actor!
      if to <= from || to - from > MAX_RANGE
        raise ApiError.invalid("Ask for a period of up to #{MAX_RANGE.in_days.to_i} days.")
      end

      Booking.overlapping(from, to).where.not(status: "cancelled").chronological
    end

    def my_bookings
      Booking.where(membership: actor!).where(ends_at: (now - 7.days)..).chronological
    end

    def notification_templates
      admin!
      stored = NotificationTemplate.all.index_by(&:kind)
      NotificationTemplate::KINDS.map do |kind|
        template = stored[kind]
        wording = template ? { subject: template.subject, body: template.body } : Notifications::Defaults.for(kind)
        wording.merge(kind:, is_default: template.nil?)
      end
    end

    def template_tags
      Notifications::TemplateRenderer::TAGS.map { |name, description| { name:, description: } }
    end

    def template_preview(subject:, body:)
      admin!
      renderer = Notifications::TemplateRenderer
      problems = (renderer.problems(subject).map { |problem| "The subject #{problem}." } +
                  renderer.problems(body).map { |problem| "The message #{problem}." })
      return { subject:, body:, problems: } if problems.any?

      values = renderer.sample_values(object)
      { subject: renderer.render(subject, values), body: renderer.render(body, values), problems: [] }
    end

    def deliveries(first:, after: nil)
      staff!
      Cursor.page(Delivery.all, first:, after:)
    end

    def queued_deliveries
      staff!
      Delivery.queued.count
    end
  end
end
