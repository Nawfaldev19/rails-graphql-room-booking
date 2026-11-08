module Bookings
  # Who may do what to a booking. Kept apart from the actions so that the API can
  # also ask "may I?" and show or hide buttons with the same answers.
  class Policy
    CHECK_IN_OPENS = 15.minutes

    def initialize(actor, booking, now: Time.current)
      @actor = actor
      @booking = booking
      @now = now
    end

    def staff? = @actor.manages_bookings?
    def own? = @booking.membership_id == @actor.id

    # Names, notes and reasons are visible to the person booked and to staff.
    def see_details? = staff? || own?

    def reschedule?
      return false unless @booking.status == "booked"

      staff? || (own? && @booking.starts_at > @now)
    end

    # Staff may also cancel a booking that has started or passed. That records
    # what happened without pretending the booking never existed.
    def cancel?
      return false unless @booking.active?

      staff? || (own? && @booking.starts_at > @now)
    end

    def check_in?
      staff? && @booking.status == "booked" &&
        @now >= @booking.starts_at - CHECK_IN_OPENS && @now <= @booking.ends_at
    end

    def mark_missed?
      staff? && @booking.status == "booked" && @now > @booking.starts_at
    end
  end
end
