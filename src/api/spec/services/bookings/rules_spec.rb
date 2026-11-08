require "rails_helper"

RSpec.describe Bookings::Rules do
  def issues(from, to, membership: student, by_staff: false, in_room: room, ignore: nil, now: Time.current)
    in_north do
      described_class.check(workspace: north, room: in_room, membership:, starts_at: from, ends_at: to,
                            now:, by_staff:, ignore:)
    end
  end

  def messages(...) = issues(...).map(&:message)

  it "accepts an ordinary booking" do
    expect(issues(at(14), at(15))).to eq([])
  end

  it "needs both times, in the right order" do
    expect(messages(nil, at(15))).to eq([ "Choose a start and an end time." ])
    expect(messages(at(15), at(14))).to eq([ "The end must be after the start." ])
    expect(messages(at(15), at(15))).to eq([ "The end must be after the start." ])
  end

  it "keeps bookings on the half-hour grid" do
    expect(messages(at(14, 10), at(15, 10))).to eq([ "Bookings start and end on the hour or the half hour." ])
    expect(issues(at(14, 30), at(15))).to eq([])
  end

  it "limits the length to between thirty minutes and three hours" do
    expect(issues(at(14), at(14, 30))).to eq([])
    expect(issues(at(14), at(17))).to eq([])
    expect(messages(at(14), at(17, 30))).to eq([ "A booking lasts at most 3 hours." ])
  end

  it "reports every broken rule at once, each tied to a field" do
    found = issues(at(14, 5), at(14, 20))
    expect(found.map(&:field)).to eq(%w[startsAt endsAt])
  end

  describe "opening hours" do
    let(:short_day) { room(north, "Drums", opens_minute: 10 * 60, closes_minute: 20 * 60) }

    it "allows the first and the last slot of the day" do
      expect(issues(at(10), at(11), in_room: short_day)).to eq([])
      expect(issues(at(19), at(20), in_room: short_day)).to eq([])
    end

    it "refuses a booking that starts early or ends late, and says when the room is open" do
      expect(messages(at(9, 30), at(10, 30), in_room: short_day)).to eq([ "Drums is open from 10:00 to 20:00." ])
      expect(messages(at(19, 30), at(20, 30), in_room: short_day)).to eq([ "Drums is open from 10:00 to 20:00." ])
    end

    it "lets a room that closes at midnight be booked up to midnight, but not past it" do
      late = room(north, "Late room", opens_minute: 8 * 60, closes_minute: 1440)
      expect(issues(at(22), Time.utc(2025, 3, 4, 0, 0), in_room: late)).to eq([])
      expect(messages(at(23), Time.utc(2025, 3, 4, 0, 30),
                      in_room: late)).to eq([ "Late room is open from 08:00 to 24:00." ])
    end

    it "uses the school's wall clock, not UTC, when the clocks have changed" do
      # Lisbon moves to summer time on 30 March 2025: 08:00 there is 07:00 UTC.
      travel_to Time.utc(2025, 3, 28, 9, 0)
      expect(issues(Time.utc(2025, 3, 31, 7, 0), Time.utc(2025, 3, 31, 8, 0))).to eq([])
      expect(messages(Time.utc(2025, 3, 31, 6, 0), Time.utc(2025, 3, 31, 7, 0)))
        .to eq([ "Room 1 is open from 08:00 to 22:00." ])
      # The same UTC hour on the Friday before the change is 07:00 local: closed.
      expect(messages(Time.utc(2025, 3, 28, 7, 0), Time.utc(2025, 3, 28, 8, 0)).first)
        .to eq("Room 1 is open from 08:00 to 22:00.")
    end
  end

  describe "the past" do
    it "is closed to students and open to staff" do
      expect(messages(at(8), at(9))).to eq([ "This time has already passed." ])
      expect(issues(at(8), at(9), membership: staff, by_staff: true)).to eq([])
    end
  end

  describe "the weekly limit" do
    before { north.update!(weekly_limit_minutes: 180) }

    it "counts a student's active bookings in the same Monday-to-Sunday week" do
      book(student, from: at(10), to: at(12))
      expect(issues(at(14), at(15))).to eq([])
      expect(messages(at(14), at(15, 30))).to eq([ "This would go over the weekly limit of 3 hours." ])
    end

    it "starts again the following Monday" do
      book(student, from: at(10), to: at(13))
      expect(messages(at(14, day: 6), at(15, day: 6))).to eq([ "This would go over the weekly limit of 3 hours." ])
      expect(issues(at(14, day: 7), at(15, day: 7))).to eq([])
    end

    it "does not count cancelled bookings or other people's" do
      mine = book(student, from: at(10), to: at(13))
      book(other_student, from: at(15), to: at(18))
      in_north { Bookings::Actions.new(student).cancel(booking_id: mine.id) }
      expect(issues(at(18), at(21))).to eq([])
    end

    it "does not count the booking that is being moved" do
      existing = book(student, from: at(10), to: at(13))
      expect(issues(at(14), at(17), ignore: existing)).to eq([])
    end

    it "does not apply to staff" do
      expect(issues(at(10), at(13), membership: staff, by_staff: true)).to eq([])
      book(staff, from: at(10), to: at(13))
      expect(issues(at(14), at(17), membership: staff, by_staff: true)).to eq([])
    end

    it "words a half-hour limit correctly" do
      north.update!(weekly_limit_minutes: 90)
      expect(messages(at(14), at(16))).to eq([ "This would go over the weekly limit of 1.5 hours." ])
    end
  end
end
