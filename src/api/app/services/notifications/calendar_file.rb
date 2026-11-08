module Notifications
  # Builds an iCalendar file (RFC 5545) for one booking, so it can be added to
  # any calendar app. Written by hand because the format needed here is small:
  # one event, in UTC, with the escaping and line folding the standard requires.
  class CalendarFile
    PRODUCT = "-//Room Booking//Room bookings//EN".freeze
    MAX_LINE_OCTETS = 75

    # `room` and `workspace` can be passed in by a caller that has already loaded
    # them (the API does, to build many files without a query for each).
    def self.build(booking, cancelled: false, now: Time.current, room: booking.room, workspace: booking.workspace)
      new(booking, cancelled:, now:, room:, workspace:).to_s
    end

    def initialize(booking, cancelled:, now:, room:, workspace:)
      @booking = booking
      @cancelled = cancelled
      @now = now
      @room = room
      @workspace = workspace
    end

    def to_s
      lines = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:#{PRODUCT}",
        "CALSCALE:GREGORIAN",
        "METHOD:#{@cancelled ? 'CANCEL' : 'REQUEST'}",
        "BEGIN:VEVENT",
        "UID:booking-#{@booking.id}@room-booking.example",
        # A higher sequence tells calendar apps that this replaces what they have.
        "SEQUENCE:#{@booking.lock_version}",
        "DTSTAMP:#{stamp(@now)}",
        "DTSTART:#{stamp(@booking.starts_at)}",
        "DTEND:#{stamp(@booking.ends_at)}",
        "SUMMARY:#{escape("#{@room.name} (#{@workspace.name})")}",
        "LOCATION:#{escape(@room.name)}",
        "STATUS:#{@cancelled ? 'CANCELLED' : 'CONFIRMED'}",
        "END:VEVENT",
        "END:VCALENDAR"
      ]
      "#{lines.flat_map { |line| fold(line) }.join("\r\n")}\r\n"
    end

    # Backslash, semicolon and comma have meaning in the format; newlines become "\n".
    def self.escape(text)
      text.to_s.gsub("\\", "\\\\\\\\").gsub(";", ";").gsub(",", "\\,").gsub(/\r?\n/, "\\n")
    end

    # Lines longer than 75 octets continue on the next line after one space.
    # Splitting counts bytes but never cuts a multi-byte character in half.
    def self.fold(line)
      return [ line ] if line.bytesize <= MAX_LINE_OCTETS

      parts = []
      current = +""
      line.each_char do |char|
        limit = parts.empty? ? MAX_LINE_OCTETS : MAX_LINE_OCTETS - 1
        if current.bytesize + char.bytesize > limit
          parts << current
          current = +""
        end
        current << char
      end
      parts << current
      [ parts.first, *parts.drop(1).map { |part| " #{part}" } ]
    end

    private

    def escape(text) = self.class.escape(text)
    def fold(line) = self.class.fold(line)
    def stamp(time) = time.utc.strftime("%Y%m%dT%H%M%SZ")
  end
end
