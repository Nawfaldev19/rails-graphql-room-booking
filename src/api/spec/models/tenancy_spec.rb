require "rails_helper"

# The promise: one workspace can never read or change another workspace's data.
# These specs attack it at the model layer and at the database itself.
RSpec.describe "Tenant isolation in the data layer" do
  let!(:north_room) { room(north, "North room") }
  let!(:south_room) { room(south, "South room") }
  let!(:south_booking) { book(south_admin, in_room: south_room) }

  describe "without a current workspace" do
    it "refuses to query, instead of returning every workspace's rows" do
      expect { Room.count }.to raise_error(Tenancy::NotSet)
      expect { Booking.first }.to raise_error(Tenancy::NotSet)
      expect { Delivery.where(status: "sent").to_a }.to raise_error(Tenancy::NotSet)
    end

    it "refuses to create" do
      expect { Room.create!(name: "Orphan") }.to raise_error(Tenancy::NotSet)
    end

    it "requires a workspace to enter one" do
      expect { Tenancy.with(nil) { :unreachable } }.to raise_error(ArgumentError)
    end
  end

  describe "inside a workspace" do
    it "sees only its own rows" do
      in_north do
        expect(Room.pluck(:name)).to eq([ "North room" ])
        expect(Booking.count).to eq(0)
        expect(Delivery.count).to eq(0)
      end
    end

    it "cannot find another workspace's record by id" do
      in_north do
        expect(Room.find_by(id: south_room.id)).to be_nil
        expect { Booking.find(south_booking.id) }.to raise_error(ActiveRecord::RecordNotFound)
        expect(Booking.where(id: south_booking.id).update_all(note: "defaced")).to eq(0)
        expect(Booking.where(id: south_booking.id).delete_all).to eq(0)
      end
      Tenancy.with(south) { expect(Booking.find(south_booking.id).note).to be_nil }
    end

    it "places new records in the current workspace" do
      in_north { expect(Room.create!(name: "Fresh").workspace).to eq(north) }
    end

    it "refuses a record that names another workspace" do
      in_north do
        intruder = Room.new(name: "Smuggled", workspace: south)
        expect(intruder).not_to be_valid
        expect(intruder.errors[:workspace]).to include("must be the current workspace")
      end
    end

    it "cannot move a record to another workspace" do
      in_north do
        expect { north_room.update!(workspace_id: south.id) }
          .to raise_error(ActiveRecord::ReadonlyAttributeError)
        expect(north_room.reload.workspace_id).to eq(north.id)
      end
    end

    it "restores the previous workspace after a nested block" do
      in_north do
        Tenancy.with(south) { expect(Room.pluck(:name)).to eq([ "South room" ]) }
        expect(Room.pluck(:name)).to eq([ "North room" ])
      end
      expect(Tenancy.current).to be_nil
    end
  end

  describe "in the database" do
    it "rejects a booking that joins one workspace to another workspace's room" do
      expect do
        ActiveRecord::Base.connection.execute(<<~SQL.squish)
          INSERT INTO bookings (workspace_id, room_id, membership_id, created_by_id, starts_at, ends_at,
                                created_at, updated_at)
          VALUES (#{north.id}, #{south_room.id}, #{admin.id}, #{admin.id},
                  '2025-03-04 10:00:00', '2025-03-04 11:00:00', '2025-03-03', '2025-03-03')
        SQL
      end.to raise_error(ActiveRecord::InvalidForeignKey)
    end

    it "rejects a booking for a person from another workspace" do
      expect do
        ActiveRecord::Base.connection.execute(<<~SQL.squish)
          INSERT INTO bookings (workspace_id, room_id, membership_id, created_by_id, starts_at, ends_at,
                                created_at, updated_at)
          VALUES (#{north.id}, #{north_room.id}, #{south_admin.id}, #{admin.id},
                  '2025-03-04 10:00:00', '2025-03-04 11:00:00', '2025-03-03', '2025-03-03')
        SQL
      end.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end

  describe "coverage of the rule" do
    it "applies to every table that carries a workspace id" do
      Rails.application.eager_load!
      tables = ActiveRecord::Base.connection.tables.select do |table|
        ActiveRecord::Base.connection.column_exists?(table, :workspace_id)
      end
      # Memberships are the bridge between users and workspaces (see the model).
      scoped = ApplicationRecord.descendants.select { |model| model.include?(TenantScoped) }.map(&:table_name)

      expect(tables - [ "memberships" ]).to match_array(scoped)
      expect(scoped).to include("rooms", "bookings", "deliveries")
    end

    it "is never switched off: no code under app/ calls unscoped" do
      offenders = Rails.root.glob("app/**/*.rb").select do |file|
        file.read.lines.any? { |line| line.include?("unscoped") && !line.lstrip.start_with?("#") }
      end
      expect(offenders.map { |file| file.relative_path_from(Rails.root).to_s }).to eq([])
    end
  end
end
