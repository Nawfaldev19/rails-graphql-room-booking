# The whole schema in one migration.
#
# Three things here are not ordinary column definitions:
#   * composite foreign keys (workspace_id, id), so a row can never point at a
#     parent in another workspace;
#   * check constraints for the few values the code depends on;
#   * two triggers that refuse overlapping bookings in the same room. They make
#     "one room, one booking at a time" a property of the data, whatever the
#     application does and however many requests arrive at once.
class CreateSchema < ActiveRecord::Migration[8.1]
  ACTIVE = "('booked', 'checked_in')".freeze

  def up
    create_table :workspaces do |t|
      t.string :name, null: false
      t.string :time_zone, null: false, default: "UTC"
      t.integer :weekly_limit_minutes, null: false, default: 360
      t.json :status_labels, null: false, default: {}
      t.timestamps
    end

    create_table :users do |t|
      t.string :email, null: false, index: { unique: true }
      t.string :name, null: false
      t.string :password_digest, null: false
      t.timestamps
    end

    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false, index: { unique: true }
      t.datetime :expires_at, null: false
      t.timestamps
    end

    create_table :memberships do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false
      # Asked once, before a student's first booking.
      t.string :instrument
      t.string :phone
      t.timestamps
      t.index %i[workspace_id user_id], unique: true
      t.index %i[workspace_id id], unique: true
      t.check_constraint "role IN ('admin', 'staff', 'student')", name: "memberships_role"
    end

    create_table :rooms do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :capacity, null: false, default: 1
      # Opening hours as minutes after local midnight.
      t.integer :opens_minute, null: false, default: 8 * 60
      t.integer :closes_minute, null: false, default: 22 * 60
      t.json :equipment, null: false, default: []
      t.timestamps
      t.index %i[workspace_id name], unique: true
      t.index %i[workspace_id id], unique: true
      t.check_constraint "opens_minute >= 0 AND closes_minute <= 1440 AND opens_minute < closes_minute",
                         name: "rooms_hours"
    end

    create_table :bookings do |t|
      t.references :workspace, null: false, foreign_key: true
      t.bigint :room_id, null: false
      t.bigint :membership_id, null: false
      t.bigint :created_by_id, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :status, null: false, default: "booked"
      t.string :note
      t.datetime :cancelled_at
      t.string :cancel_reason
      t.boolean :cancelled_after_start, null: false, default: false
      # Optimistic locking: an edit based on stale data is refused.
      t.integer :lock_version, null: false, default: 0
      t.timestamps
      # For the calendar, for the overlap triggers, and for a person's week.
      t.index %i[workspace_id starts_at]
      t.index %i[room_id starts_at]
      t.index %i[workspace_id membership_id starts_at]
      t.check_constraint "ends_at > starts_at", name: "bookings_positive_length"
      t.check_constraint "status IN ('booked', 'checked_in', 'cancelled', 'missed')",
                         name: "bookings_status"
    end
    add_foreign_key :bookings, :rooms, column: %i[workspace_id room_id], primary_key: %i[workspace_id id]
    add_foreign_key :bookings, :memberships, column: %i[workspace_id membership_id],
                                             primary_key: %i[workspace_id id]
    add_foreign_key :bookings, :memberships, column: %i[workspace_id created_by_id],
                                             primary_key: %i[workspace_id id]

    create_table :notification_templates do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :subject, null: false
      t.text :body, null: false
      t.timestamps
      t.index %i[workspace_id kind], unique: true
      t.check_constraint "kind IN ('confirmation', 'change', 'cancellation')",
                         name: "notification_templates_kind"
    end

    create_table :notification_preferences do |t|
      t.references :workspace, null: false, foreign_key: true
      t.bigint :membership_id, null: false
      t.string :kind, null: false
      t.boolean :enabled, null: false, default: true
      t.timestamps
      t.index %i[membership_id kind], unique: true
    end
    add_foreign_key :notification_preferences, :memberships,
                    column: %i[workspace_id membership_id], primary_key: %i[workspace_id id]

    create_table :deliveries do |t|
      t.references :workspace, null: false, foreign_key: true
      t.bigint :membership_id, null: false
      t.bigint :booking_id
      t.string :kind, null: false
      t.string :to_email, null: false
      t.string :subject, null: false
      t.text :body, null: false
      t.text :calendar_file
      t.string :status, null: false, default: "queued"
      t.string :skip_reason
      t.integer :attempts, null: false, default: 0
      t.datetime :sent_at
      t.timestamps
      t.index %i[workspace_id created_at]
      t.index %i[workspace_id status]
      t.check_constraint "status IN ('queued', 'sent', 'skipped')", name: "deliveries_status"
    end
    add_foreign_key :deliveries, :memberships, column: %i[workspace_id membership_id],
                                               primary_key: %i[workspace_id id]

    # Token buckets for the outgoing-mail rate limit, one row per key.
    create_table :rate_buckets do |t|
      t.string :key, null: false, index: { unique: true }
      t.float :tokens, null: false
      t.datetime :refilled_at, null: false
    end

    execute <<~SQL
      CREATE TRIGGER bookings_no_overlap_on_insert
      BEFORE INSERT ON bookings
      WHEN NEW.status IN #{ACTIVE} AND EXISTS (
        SELECT 1 FROM bookings other
         WHERE other.room_id = NEW.room_id
           AND other.status IN #{ACTIVE}
           AND other.starts_at < NEW.ends_at
           AND other.ends_at > NEW.starts_at
      )
      BEGIN
        SELECT RAISE(ABORT, 'booking_overlap');
      END;
    SQL

    execute <<~SQL
      CREATE TRIGGER bookings_no_overlap_on_update
      BEFORE UPDATE OF room_id, starts_at, ends_at, status ON bookings
      WHEN NEW.status IN #{ACTIVE} AND EXISTS (
        SELECT 1 FROM bookings other
         WHERE other.id <> NEW.id
           AND other.room_id = NEW.room_id
           AND other.status IN #{ACTIVE}
           AND other.starts_at < NEW.ends_at
           AND other.ends_at > NEW.starts_at
      )
      BEGIN
        SELECT RAISE(ABORT, 'booking_overlap');
      END;
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
