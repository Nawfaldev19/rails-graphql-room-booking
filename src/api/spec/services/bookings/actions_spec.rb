require "rails_helper"

RSpec.describe Bookings::Actions do
  def act(actor = student, now: Time.current) = described_class.new(actor, now:)
  def run(&) = in_north(&)

  def expect_error(code, &)
    expect { run(&) }.to raise_error(ApiError) { |error| expect(error.code).to eq(code) }
  end

  before { room }

  describe "creating" do
    it "books the room for the person and queues a confirmation" do
      booking = run { act.create(room_id: room.id, starts_at: at(14), ends_at: at(15), note: " Bach ") }

      expect(booking).to have_attributes(status: "booked", membership: student, created_by: student,
                                         note: "Bach", workspace: north)
      delivery = run { Delivery.sole }
      expect(delivery).to have_attributes(kind: "confirmation", status: "queued", to_email: "mia@example.com")
      expect(delivery.subject).to eq("Booked: Room 1 on Monday 3 March 2025")
      expect(delivery.calendar_file).to include("METHOD:REQUEST")
    end

    it "is refused when the rules are broken, with nothing written" do
      expect_error("VALIDATION") { act.create(room_id: room.id, starts_at: at(14, 10), ends_at: at(15)) }
      run { expect(Booking.count).to eq(0) }
    end

    it "answers not found for a room in another workspace" do
      elsewhere = room(south, "South room")
      expect_error("NOT_FOUND") { act.create(room_id: elsewhere.id, starts_at: at(14), ends_at: at(15)) }
    end

    it "asks a student for two details before the first booking, and only until they are given" do
      newcomer = member(north, "teo", "student")
      expect { run { act(newcomer).create(room_id: room.id, starts_at: at(14), ends_at: at(15)) } }
        .to raise_error(ApiError) { |error|
          expect(error.code).to eq("PROFILE_INCOMPLETE")
          expect(error.issues.map(&:field)).to eq(%w[instrument phone])
        }

      newcomer.update!(instrument: "Oboe", phone: "555 0199")
      expect(run { act(newcomer).create(room_id: room.id, starts_at: at(14), ends_at: at(15)) }).to be_persisted
    end

    it "lets staff book for a student, and choose not to notify" do
      booking = run do
        act(staff).create(room_id: room.id, membership_id: student.id, starts_at: at(14), ends_at: at(15),
                          notify: false)
      end
      expect(booking).to have_attributes(membership: student, created_by: staff)
      run { expect(Delivery.count).to eq(0) }
    end

    it "does not let a student book for someone else" do
      expect_error("FORBIDDEN") do
        act.create(room_id: room.id, membership_id: other_student.id, starts_at: at(14), ends_at: at(15))
      end
    end

    it "does not let staff book for someone from another workspace" do
      expect_error("NOT_FOUND") do
        act(staff).create(room_id: room.id, membership_id: south_admin.id, starts_at: at(14), ends_at: at(15))
      end
    end
  end

  describe "two bookings for the same room" do
    before { book(student, from: at(14), to: at(15)) }

    it "cannot overlap, whichever way they overlap" do
      [ [ at(14), at(15) ], [ at(13, 30), at(14, 30) ], [ at(14, 30), at(15, 30) ], [ at(13), at(16) ] ].each do |from, to|
        expect { book(other_student, from:, to:) }
          .to raise_error(ApiError) { |error|
            expect(error.code).to eq("CONFLICT")
            expect(error.message).to eq("That room is already booked for part of this time.")
          }
      end
    end

    it "may touch end to start" do
      expect(book(other_student, from: at(15), to: at(16))).to be_persisted
      expect(book(other_student, from: at(13), to: at(14))).to be_persisted
    end

    it "may overlap in different rooms" do
      expect(book(other_student, from: at(14), to: at(15), in_room: room(north, "Room 2"))).to be_persisted
    end

    it "frees the slot when the first is cancelled" do
      first = run { Booking.sole }
      run { act.cancel(booking_id: first.id) }
      expect(book(other_student, from: at(14), to: at(15))).to be_persisted
    end
  end

  describe "rescheduling" do
    let!(:booking) { book(student, from: at(14), to: at(15)) }

    it "moves the booking and sends a change notice" do
      moved = run do
        act.reschedule(booking_id: booking.id, room_id: room.id, starts_at: at(16), ends_at: at(17),
                       lock_version: booking.lock_version)
      end
      expect(moved).to have_attributes(starts_at: at(16), ends_at: at(17), lock_version: 1)
      run { expect(Delivery.order(:id).pluck(:kind)).to eq(%w[confirmation change]) }
    end

    it "may keep part of its own old slot" do
      moved = run do
        act.reschedule(booking_id: booking.id, room_id: room.id, starts_at: at(14, 30), ends_at: at(15, 30),
                       lock_version: 0)
      end
      expect(moved.starts_at).to eq(at(14, 30))
    end

    it "cannot move onto another booking" do
      book(other_student, from: at(16), to: at(17))
      expect_error("CONFLICT") do
        act.reschedule(booking_id: booking.id, room_id: room.id, starts_at: at(16, 30), ends_at: at(17, 30),
                       lock_version: 0)
      end
      run { expect(booking.reload.starts_at).to eq(at(14)) }
    end

    it "is refused when it started from an outdated version" do
      run { act.reschedule(booking_id: booking.id, room_id: room.id, starts_at: at(16), ends_at: at(17), lock_version: 0) }
      expect do
        run do
          act.reschedule(booking_id: booking.id, room_id: room.id, starts_at: at(18), ends_at: at(19), lock_version: 0)
        end
      end
        .to raise_error(ApiError) { |error|
          expect(error.code).to eq("CONFLICT")
          expect(error.message).to include("Someone else changed this booking")
        }
    end

    it "is closed to the student once the booking has started, but not to staff" do
      later = at(14, 30)
      expect_error("FORBIDDEN") do
        act(student, now: later).reschedule(booking_id: booking.id, room_id: room.id, starts_at: at(16),
                                            ends_at: at(17), lock_version: 0)
      end
      moved = run do
        act(staff, now: later).reschedule(booking_id: booking.id, room_id: room.id, starts_at: at(16),
                                          ends_at: at(17), lock_version: 0)
      end
      expect(moved.starts_at).to eq(at(16))
    end

    it "hides other students' bookings: they look like they do not exist" do
      expect_error("NOT_FOUND") do
        act(other_student).reschedule(booking_id: booking.id, room_id: room.id, starts_at: at(16),
                                      ends_at: at(17), lock_version: 0)
      end
    end
  end

  describe "cancelling" do
    let!(:booking) { book(student, from: at(14), to: at(15)) }

    it "lets the person cancel their own upcoming booking without a reason" do
      cancelled = run { act.cancel(booking_id: booking.id) }
      expect(cancelled).to have_attributes(status: "cancelled", cancelled_at: Time.current,
                                           cancelled_after_start: false, cancel_reason: nil)
      run { expect(Delivery.order(:id).last.calendar_file).to include("METHOD:CANCEL") }
    end

    it "makes staff give a reason, which the notice then carries" do
      expect { run { act(staff).cancel(booking_id: booking.id, reason: "  ") } }
        .to raise_error(ApiError) { |error| expect(error.issues.map(&:field)).to eq([ "reason" ]) }

      run { act(staff).cancel(booking_id: booking.id, reason: "The piano is being tuned") }
      run { expect(Delivery.order(:id).last.body).to include("Reason: The piano is being tuned") }
    end

    it "can be done by staff without telling the person" do
      run { act(staff).cancel(booking_id: booking.id, reason: "Entered by mistake", notify: false) }
      run { expect(Delivery.pluck(:kind)).to eq([ "confirmation" ]) }
    end

    it "lets staff cancel a booking that has already started, and records that it was after the fact" do
      afterwards = at(16)
      expect_error("FORBIDDEN") { act(student, now: afterwards).cancel(booking_id: booking.id) }

      cancelled = run { act(staff, now: afterwards).cancel(booking_id: booking.id, reason: "Did not happen") }
      expect(cancelled).to have_attributes(status: "cancelled", cancelled_after_start: true)
    end

    it "cannot be done twice" do
      run { act.cancel(booking_id: booking.id) }
      expect_error("FORBIDDEN") { act(staff).cancel(booking_id: booking.id, reason: "Again") }
    end
  end

  describe "checking in and marking as missed" do
    let!(:booking) { book(student, from: at(14), to: at(15)) }

    it "is for staff only" do
      expect_error("FORBIDDEN") { act(student, now: at(14)).set_status(booking_id: booking.id, status: "checked_in") }
    end

    it "opens check-in fifteen minutes before the start and closes it at the end" do
      expect_error("FORBIDDEN") { act(staff, now: at(13, 44)).set_status(booking_id: booking.id, status: "checked_in") }
      expect_error("FORBIDDEN") { act(staff, now: at(15, 1)).set_status(booking_id: booking.id, status: "checked_in") }
      checked = run { act(staff, now: at(13, 45)).set_status(booking_id: booking.id, status: "checked_in") }
      expect(checked.status).to eq("checked_in")
    end

    it "allows marking as missed only after the start, and then frees nothing retroactively" do
      expect_error("FORBIDDEN") { act(staff, now: at(13)).set_status(booking_id: booking.id, status: "missed") }
      missed = run { act(staff, now: at(14, 20)).set_status(booking_id: booking.id, status: "missed") }
      expect(missed.status).to eq("missed")
      expect_error("FORBIDDEN") { act(staff, now: at(14, 30)).set_status(booking_id: booking.id, status: "checked_in") }
    end

    it "refuses statuses that are set by other actions" do
      expect_error("FORBIDDEN") { act(staff, now: at(14)).set_status(booking_id: booking.id, status: "cancelled") }
    end
  end
end
