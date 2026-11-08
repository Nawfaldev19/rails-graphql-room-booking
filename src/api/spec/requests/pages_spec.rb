require "rails_helper"

RSpec.describe "Pages and health" do
  it "answers the health check" do
    get "/healthz"
    expect(response.body).to eq("ok")
  end

  it "sends security headers with every response" do
    get "/healthz"
    expect(response.headers["Referrer-Policy"]).to eq("no-referrer")
    expect(response.headers["Content-Security-Policy"]).to include("default-src 'self'", "frame-ancestors 'none'")
    expect(response.headers["X-Content-Type-Options"]).to eq("nosniff")
    expect(response.headers["X-Frame-Options"]).to eq("SAMEORIGIN")
  end

  context "when the web app has been built" do
    # The public folder is build output and may not exist in a fresh checkout,
    # so this puts a stand-in page there and removes exactly what it added.
    around do |example|
      index = Rails.public_path.join("index.html")
      had_page = index.exist?
      had_folder = Rails.public_path.exist?
      Rails.public_path.mkpath
      index.write("<!doctype html><title>Room Booking</title>") unless had_page
      example.run
    ensure
      index.delete if !had_page && index.exist?
      Rails.public_path.rmdir unless had_folder
    end

    it "serves the same page for every page address, never cached" do
      %w[/ /w/1/calendar /preferences/some-token].each do |path|
        get path
        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/html")
        expect(response.headers["Cache-Control"]).to eq("no-cache")
      end
    end
  end

  it "does not answer other formats with the page" do
    get "/w/1/calendar.json"
    expect(response).to have_http_status(:not_found)
  end
end

RSpec.describe "Demo data" do
  before { load Rails.root.join("db/seeds.rb") }

  it "creates two schools, with one person in both" do
    expect(Workspace.pluck(:name)).to contain_exactly("Larkfield Music School", "Harbour Street Rehearsal Rooms")
    expect(User.find_by!(email: "odile@example.com").memberships.map do |membership|
      [ membership.workspace.name, membership.role ]
    end)
      .to contain_exactly([ "Larkfield Music School", "admin" ], [ "Harbour Street Rehearsal Rooms", "student" ])
  end

  it "uses only reserved example addresses" do
    expect(User.pluck(:email)).to all(end_with("@example.com"))
  end

  it "leaves a student who has not given their details yet" do
    teo = User.find_by!(email: "teo@example.com").memberships.sole
    expect(teo.missing_profile_details).to eq(%w[instrument phone])
  end

  it "shows bookings, a cancellation, a renamed status and a delivery log" do
    Tenancy.with(Workspace.find_by!(name: "Larkfield Music School")) do
      expect(Booking.group(:status).count).to eq("booked" => 5, "cancelled" => 1)
      expect(Tenancy.current.status_label("missed")).to eq("No-show")
      expect(Delivery.count).to be >= 6
      expect(Delivery.where(status: "sent").count).to be >= 1
      expect(NotificationTemplate.pluck(:kind)).to eq([ "confirmation" ])
    end
  end

  it "does nothing when run a second time" do
    expect { load Rails.root.join("db/seeds.rb") }.not_to change(User, :count)
  end

  it "lets the demo accounts sign in" do
    user, = Auth::SignIn.call(email: "suvi@example.com", password: "practice-demo", client_key: "spec")
    expect(user.name).to eq("Suvi Lahtinen")
  end
end
