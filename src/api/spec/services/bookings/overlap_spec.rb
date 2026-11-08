require "rails_helper"

# "One room, one booking at a time" is enforced by database triggers. These
# specs go around the application on purpose, to show the rule holds anyway.
RSpec.describe "Overlap protection in the database" do
  let!(:existing) { book(student, from: at(14), to: at(15)) }

  def insert(from, to, status: "booked", room_id: room.id)
    ActiveRecord::Base.connection.execute(<<~SQL.squish)
      INSERT INTO bookings (workspace_id, room_id, membership_id, created_by_id, starts_at, ends_at, status,
                            created_at, updated_at)
      VALUES (#{north.id}, #{room_id}, #{student.id}, #{student.id}, '#{from.utc.to_fs(:db)}',
              '#{to.utc.to_fs(:db)}', '#{status}', '2025-03-03', '2025-03-03')
    SQL
  end

  it "has both triggers installed" do
    names = ActiveRecord::Base.connection.select_values("SELECT name FROM sqlite_master WHERE type = 'trigger'")
    expect(names).to contain_exactly("bookings_no_overlap_on_insert", "bookings_no_overlap_on_update")
  end

  it "rejects a raw insert that overlaps" do
    expect { insert(at(14, 30), at(15, 30)) }.to raise_error(ActiveRecord::StatementInvalid, /booking_overlap/)
  end

  it "accepts a raw insert next to it, in another room, or with a status that holds no room" do
    expect { insert(at(15), at(16)) }.not_to raise_error
    expect { insert(at(14), at(15), room_id: room(north, "Room 2").id) }.not_to raise_error
    expect { insert(at(14), at(15), status: "cancelled") }.not_to raise_error
    expect { insert(at(14), at(15), status: "missed") }.not_to raise_error
  end

  it "rejects an update that moves a booking onto another" do
    other = book(other_student, from: at(16), to: at(17))
    expect do
      ActiveRecord::Base.connection.execute(
        "UPDATE bookings SET starts_at = '2025-03-03 14:30:00', ends_at = '2025-03-03 15:30:00' WHERE id = #{other.id}"
      )
    end.to raise_error(ActiveRecord::StatementInvalid, /booking_overlap/)
  end

  it "rejects bringing a cancelled booking back onto a slot that was taken since" do
    insert(at(14), at(15), status: "cancelled")
    cancelled_id = ActiveRecord::Base.connection.select_value("SELECT MAX(id) FROM bookings")
    expect do
      ActiveRecord::Base.connection.execute("UPDATE bookings SET status = 'booked' WHERE id = #{cancelled_id}")
    end.to raise_error(ActiveRecord::StatementInvalid, /booking_overlap/)
  end

  it "rejects a booking that ends before it starts" do
    expect { insert(at(17), at(16)) }.to raise_error(ActiveRecord::StatementInvalid, /bookings_positive_length/)
  end

  it "rejects a status the code does not know" do
    expect { insert(at(18), at(19), status: "pencilled") }.to raise_error(ActiveRecord::StatementInvalid, /bookings_status/)
  end
end

# Real simultaneous requests, each on its own database connection. This cannot
# run inside the usual per-test transaction, so it cleans up after itself.
RSpec.describe "Two people booking the same slot at the same moment" do
  self.use_transactional_tests = false

  after do
    %w[deliveries bookings rooms memberships sessions users workspaces rate_buckets].each do |table|
      ActiveRecord::Base.connection.execute("DELETE FROM #{table}")
    end
  end

  it "gives the room to exactly one of them" do
    people = [ student, other_student, staff, admin ]
    target = room
    go = Concurrent::CountDownLatch.new(1)

    outcomes = people.map do |person|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          go.wait
          Tenancy.with(north) do
            Bookings::Actions.new(person).create(room_id: target.id, starts_at: at(14), ends_at: at(15), notify: false)
          end
          :booked
        rescue ApiError => e
          e.code
        end
      end
    end
    go.count_down
    results = outcomes.map(&:value)

    expect(results.count(:booked)).to eq(1)
    expect(results.count("CONFLICT")).to eq(people.size - 1)
    Tenancy.with(north) { expect(Booking.active.count).to eq(1) }
  end
end
