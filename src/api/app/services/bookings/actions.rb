module Bookings
  # Every change to a booking goes through one of these methods. Each checks
  # permission, applies the rules, writes inside the current workspace, and then
  # hands over to the notification dispatcher.
  class Actions
    OVERLAP_MESSAGE = "That room is already booked for part of this time.".freeze

    def initialize(actor, now: Time.current)
      @actor = actor
      @now = now
      @workspace = Tenancy.current!
    end

    def create(room_id:, starts_at:, ends_at:, membership_id: nil, note: nil, notify: true)
      person = person_for(membership_id)
      require_profile!(person)
      room = Room.find_by(id: room_id) || raise(ApiError.not_found("Room"))
      check_rules!(room:, person:, starts_at:, ends_at:)

      booking = write do
        Booking.create!(room:, membership: person, created_by: @actor, starts_at:, ends_at:,
                        note: note.to_s.strip.presence)
      end
      announce(booking, "confirmation") if person == @actor || notify
      booking
    end

    def reschedule(booking_id:, room_id:, starts_at:, ends_at:, lock_version:, notify: true)
      booking = find(booking_id)
      raise ApiError.forbidden("This booking can no longer be changed.") unless policy(booking).reschedule?

      room = Room.find_by(id: room_id) || raise(ApiError.not_found("Room"))
      check_rules!(room:, person: booking.membership, starts_at:, ends_at:, ignore: booking)

      write do
        booking.lock_version = lock_version
        booking.update!(room:, starts_at:, ends_at:)
      end
      announce(booking, "change") if booking.membership == @actor || notify
      booking
    end

    def cancel(booking_id:, reason: nil, notify: true)
      booking = find(booking_id)
      raise ApiError.forbidden("This booking can no longer be cancelled.") unless policy(booking).cancel?

      reason = reason.to_s.strip
      by_someone_else = booking.membership != @actor
      if by_someone_else && reason.empty?
        raise ApiError.invalid("Give a reason.", [ ApiError::Issue.new("reason", "Say why this booking is cancelled.") ])
      end

      write do
        booking.update!(status: "cancelled", cancelled_at: @now, cancel_reason: reason.presence,
                        cancelled_after_start: @now >= booking.starts_at)
      end
      announce(booking, "cancellation") if !by_someone_else || notify
      booking
    end

    def set_status(booking_id:, status:)
      booking = find(booking_id)
      allowed = case status
                when "checked_in" then policy(booking).check_in?
                when "missed" then policy(booking).mark_missed?
                else false
                end
      raise ApiError.forbidden("This booking cannot be marked that way now.") unless allowed

      write { booking.update!(status:) }
      booking
    end

    private

    def policy(booking) = Policy.new(@actor, booking, now: @now)

    def find(id)
      booking = Booking.find_by(id:)
      # A student asking for someone else's booking gets the same answer as for
      # one that does not exist.
      raise ApiError.not_found("Booking") if booking.nil? || !policy(booking).see_details?

      booking
    end

    def person_for(membership_id)
      return @actor if membership_id.blank? || membership_id.to_s == @actor.id.to_s
      raise ApiError.forbidden("Only staff can book for someone else.") unless @actor.manages_bookings?

      @workspace.memberships.find_by(id: membership_id) || raise(ApiError.not_found("Person"))
    end

    # Students give two details before their first booking, once.
    def require_profile!(person)
      return unless person == @actor && person.student?

      missing = person.missing_profile_details
      return if missing.empty?

      issues = missing.map { |detail| ApiError::Issue.new(detail, "Tell us your #{detail} before your first booking.") }
      raise ApiError.new("PROFILE_INCOMPLETE", "Two details are needed before your first booking.", issues:)
    end

    def check_rules!(room:, person:, starts_at:, ends_at:, ignore: nil)
      issues = Rules.check(workspace: @workspace, room:, membership: person, starts_at:, ends_at:,
                           now: @now, by_staff: @actor.manages_bookings?, ignore:)
      raise ApiError.invalid("This booking is not possible.", issues) if issues.any?
    end

    # Runs a write and translates what the database may refuse.
    def write
      yield
    rescue ActiveRecord::StaleObjectError
      raise ApiError.conflict("Someone else changed this booking. Reload to see the latest version.")
    rescue ActiveRecord::RecordInvalid => e
      raise ApiError.from_record(e.record)
    rescue ActiveRecord::StatementInvalid => e
      raise unless e.message.include?("booking_overlap")

      raise ApiError.conflict(OVERLAP_MESSAGE)
    end

    def announce(booking, kind)
      Notifications::Dispatcher.booking_event(booking, kind)
    end
  end
end
