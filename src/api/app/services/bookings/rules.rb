module Bookings
  # The rules a booking must satisfy, apart from "the room is free" (which the
  # database enforces). Pure decisions over values that are passed in: no writes,
  # and the current time is an argument, so every rule can be tested directly.
  class Rules
    SLOT_MINUTES = 30
    MIN_MINUTES = 30
    MAX_MINUTES = 180

    def self.check(...) = new(...).issues

    def initialize(workspace:, room:, membership:, starts_at:, ends_at:, now:, by_staff:, ignore: nil)
      @workspace = workspace
      @room = room
      @membership = membership
      @starts_at = starts_at
      @ends_at = ends_at
      @now = now
      @by_staff = by_staff
      @ignore = ignore
    end

    def issues
      return [ issue("startsAt", "Choose a start and an end time.") ] if @starts_at.nil? || @ends_at.nil?
      return [ issue("endsAt", "The end must be after the start.") ] if @ends_at <= @starts_at

      shape_issues + timing_issues
    end

    private

    # About the booking on its own: the grid and its length.
    def shape_issues
      found = []
      found << issue("startsAt", "Bookings start and end on the hour or the half hour.") unless on_grid?
      found << issue("endsAt", "A booking lasts at least #{MIN_MINUTES} minutes.") if minutes < MIN_MINUTES
      found << issue("endsAt", "A booking lasts at most #{MAX_MINUTES / 60} hours.") if minutes > MAX_MINUTES
      found
    end

    # About where it falls: opening hours, the past, and the person's week.
    def timing_issues
      found = []
      found << issue("startsAt", opening_hours_message) unless within_opening_hours?
      found << issue("startsAt", "This time has already passed.") if !@by_staff && @starts_at < @now
      found << issue("endsAt", weekly_limit_message) if over_weekly_limit?
      found
    end

    def issue(field, message) = ApiError::Issue.new(field, message)

    def opening_hours_message
      "#{@room.name} is open from #{clock(@room.opens_minute)} to #{clock(@room.closes_minute)}."
    end

    def zone = @workspace.zone
    def local_start = @starts_at.in_time_zone(zone)
    def local_end = @ends_at.in_time_zone(zone)
    def minutes = ((@ends_at - @starts_at) / 60).round

    def on_grid?
      [ local_start, local_end ].all? { |time| (time.min % SLOT_MINUTES).zero? && time.sec.zero? }
    end

    # Wall-clock minutes after local midnight. An end at midnight counts as 24:00
    # of the starting day, so a room that closes at midnight can be booked to it.
    def within_opening_hours?
      start_minute = (local_start.hour * 60) + local_start.min
      end_minute = (local_end.hour * 60) + local_end.min
      if local_end.to_date == local_start.to_date + 1 && end_minute.zero?
        end_minute = 1440
      elsif local_end.to_date != local_start.to_date
        return false
      end
      start_minute >= @room.opens_minute && end_minute <= @room.closes_minute
    end

    # Students may hold a limited number of booked minutes per calendar week
    # (Monday to Sunday in the workspace's time zone).
    def over_weekly_limit?
      return false unless @membership.student?

      week_start = local_start.beginning_of_week(:monday)
      others = Booking.active.where(membership: @membership)
                      .where(starts_at: week_start...(week_start + 7.days))
      others = others.where.not(id: @ignore.id) if @ignore
      already = others.sum(&:minutes)
      already + minutes > @workspace.weekly_limit_minutes
    end

    def weekly_limit_message
      hours = @workspace.weekly_limit_minutes / 60.0
      shown = hours == hours.to_i ? hours.to_i : hours
      "This would go over the weekly limit of #{shown} hours."
    end

    def clock(minute) = format("%<hours>02d:%<minutes>02d", hours: minute / 60, minutes: minute % 60)
  end
end
