require "rails_helper"

RSpec.describe Workspace do
  describe "status labels" do
    it "uses the default words until a workspace chooses its own" do
      expect(north.status_label("missed")).to eq("Missed")
      north.update!(status_labels: { "missed" => "No-show" })
      expect(north.status_label(:missed)).to eq("No-show")
      expect(north.all_status_labels).to eq(
        "booked" => "Booked", "checked_in" => "Checked in", "cancelled" => "Cancelled", "missed" => "No-show"
      )
    end

    it "treats a blank label as 'use the default'" do
      north.update!(status_labels: { "booked" => "  " })
      expect(north.status_label("booked")).to eq("Booked")
    end

    it "only renames: it cannot add a status" do
      north.status_labels = { "pencilled" => "Pencilled in" }
      expect(north).not_to be_valid
      expect(north.errors[:status_labels]).to include("cannot add the status pencilled")
    end

    it "refuses labels that are too long, the same as each other, or not a set of pairs" do
      north.status_labels = { "booked" => "x" * 25 }
      expect(north.errors_on_labels).to include("for booked is too long (24 characters at most)")

      north.status_labels = { "booked" => "Missed" }
      expect(north.errors_on_labels).to include("must be different from each other")

      north.status_labels = [ "booked" ]
      expect(north.errors_on_labels).to include("must be a set of status and label pairs")
    end
  end

  it "needs a real time zone and a sensible weekly limit" do
    expect(described_class.new(name: "X", time_zone: "Mars/Olympus")).not_to be_valid
    expect(described_class.new(name: "X", weekly_limit_minutes: 0)).not_to be_valid
    expect(described_class.new(name: "X", time_zone: "Asia/Tokyo")).to be_valid
  end

  def north
    super.tap do |workspace|
      workspace.define_singleton_method(:errors_on_labels) do
        validate
        errors[:status_labels]
      end
    end
  end
end

RSpec.describe User do
  it "normalizes the email and requires it to be unique and well formed" do
    described_class.create!(name: "Ada", email: "  Ada@Example.COM ", password: World::PASSWORD)
    expect(described_class.sole.email).to eq("ada@example.com")
    expect(described_class.new(name: "Twin", email: "ADA@example.com", password: "x")).not_to be_valid
    expect(described_class.new(name: "Odd", email: "not-an-email", password: "x")).not_to be_valid
  end
end

RSpec.describe Session do
  it "stores only a digest of the token and finds the user by the token" do
    token, session = described_class.start(user("ada"))
    expect(session.token_digest).to eq(Digest::SHA256.hexdigest(token))
    expect(described_class.pluck(:token_digest)).not_to include(token)
    expect(described_class.find_user(token)).to eq(user("ada"))
  end

  it "stops working when it expires, and never matches a blank or wrong token" do
    token, = described_class.start(user("ada"), ttl: 1.hour)
    expect(described_class.find_user("")).to be_nil
    expect(described_class.find_user(nil)).to be_nil
    expect(described_class.find_user("#{token}x")).to be_nil
    travel 61.minutes
    expect(described_class.find_user(token)).to be_nil
  end
end

RSpec.describe Membership do
  it "knows roles and who manages bookings" do
    expect(admin).to be_admin.and be_manages_bookings
    expect(staff).to be_staff.and be_manages_bookings
    expect(student).to be_student
    expect(student).not_to be_manages_bookings
    expect(north.memberships.new(user: user("x"), role: "owner")).not_to be_valid
  end

  it "lists the profile details that are still missing" do
    newcomer = member(north, "teo", "student")
    expect(newcomer.missing_profile_details).to eq(%w[instrument phone])
    newcomer.update!(instrument: "Oboe")
    expect(newcomer.missing_profile_details).to eq(%w[phone])
    expect(student.missing_profile_details).to eq([])
  end

  it "allows one membership per user and workspace, and a plain phone number" do
    expect(north.memberships.new(user: student.user, role: "staff")).not_to be_valid
    student.phone = "call me maybe"
    expect(student).not_to be_valid
  end
end

RSpec.describe Room do
  it "validates its name, capacity and hours" do
    in_north do
      room
      expect(described_class.new(name: "Room 1")).not_to be_valid
      expect(described_class.new(name: "Tiny", capacity: 0)).not_to be_valid
      late = described_class.new(name: "Backwards", opens_minute: 600, closes_minute: 540)
      expect(late).not_to be_valid
      expect(late.errors[:closes_minute]).to eq([ "must be after the opening time" ])
    end
    Tenancy.with(south) { expect(described_class.new(name: "Room 1")).to be_valid }
  end
end
