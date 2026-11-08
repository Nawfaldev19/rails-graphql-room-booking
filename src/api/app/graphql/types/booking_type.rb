module Types
  class BookingType < BaseObject
    description "A room held for a person. Students see other people's bookings without names."

    field :id, ID, null: false
    field :starts_at, GraphQL::Types::ISO8601DateTime, null: false
    field :ends_at, GraphQL::Types::ISO8601DateTime, null: false
    field :status, BookingStatusEnum, null: false
    field :status_label, String, null: false
    field :lock_version, Integer, null: false
    field :room, RoomType, null: false
    field :is_mine, Boolean, null: false
    field :person_id, ID
    field :person_name, String
    field :note, String
    field :cancel_reason, String
    field :cancelled_after_start, Boolean, null: false
    field :calendar_file, String, description: "An iCalendar file for this booking."
    field :can_reschedule, Boolean, null: false
    field :can_cancel, Boolean, null: false
    field :can_check_in, Boolean, null: false
    field :can_mark_missed, Boolean, null: false

    def policy
      @policy ||= Bookings::Policy.new(actor!, object, now:)
    end

    def status_label = Tenancy.current!.status_label(object.status)
    def room = dataloader.with(Sources::Record, Room).load(object.room_id)
    def is_mine = policy.own?
    def person_id = (object.membership_id if policy.see_details?)
    def note = (object.note if policy.see_details?)
    def cancel_reason = (object.cancel_reason if policy.see_details?)
    def can_reschedule = policy.reschedule?
    def can_cancel = policy.cancel?
    def can_check_in = policy.check_in?
    def can_mark_missed = policy.mark_missed?

    def person_name
      return nil unless policy.see_details?

      dataloader.with(Sources::Record, Membership, includes: :user).load(object.membership_id).user.name
    end

    def calendar_file
      return nil unless policy.see_details?

      Notifications::CalendarFile.build(object, cancelled: object.status == "cancelled", now:, room:,
                                                workspace: Tenancy.current!)
    end
  end
end
