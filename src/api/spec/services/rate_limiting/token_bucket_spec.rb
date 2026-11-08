require "rails_helper"

RSpec.describe RateLimiting::TokenBucket do
  let(:clock) { Struct.new(:now).new(Time.utc(2025, 1, 1)) }

  def bucket(store, capacity: 3, per_second: 1.0)
    described_class.new(store:, capacity:, refill_per_second: per_second, clock: -> { clock.now })
  end

  def takes(limiter, count, key = "k") = Array.new(count) { limiter.take(key) }

  shared_examples "a bucket store" do
    it "allows a burst up to the capacity, then refuses" do
      limiter = bucket(store)
      expect(takes(limiter, 5)).to eq([ true, true, true, false, false ])
    end

    it "refills over time, up to the capacity and no further" do
      limiter = bucket(store)
      takes(limiter, 3)
      clock.now += 1.5
      expect(takes(limiter, 2)).to eq([ true, false ])
      clock.now += 0.5
      expect(limiter.take("k")).to be(true)
      clock.now += 3600
      expect(takes(limiter, 4)).to eq([ true, true, true, false ])
    end

    it "keeps separate buckets per key" do
      limiter = bucket(store, capacity: 1)
      expect(limiter.take("a")).to be(true)
      expect(limiter.take("a")).to be(false)
      expect(limiter.take("b")).to be(true)
    end

    it "does not charge for a refused attempt" do
      limiter = bucket(store, capacity: 1, per_second: 0.5)
      limiter.take("k")
      10.times { limiter.take("k") }
      clock.now += 2
      expect(limiter.take("k")).to be(true)
    end

    it "says how long to wait for the next token" do
      limiter = bucket(store, capacity: 2, per_second: 0.5)
      expect(limiter.wait_time("k")).to eq(0.0)
      takes(limiter, 2)
      expect(limiter.wait_time("k")).to eq(2.0)
      clock.now += 1
      expect(limiter.wait_time("k")).to eq(1.0)
    end

    it "ignores a clock that goes backwards" do
      limiter = bucket(store, capacity: 1)
      limiter.take("k")
      clock.now -= 60
      expect(limiter.take("k")).to be(false)
    end
  end

  context "with the in-memory store" do
    let(:store) { RateLimiting::MemoryStore.new }

    it_behaves_like "a bucket store"

    it "forgets the oldest key when it is full" do
      small = RateLimiting::MemoryStore.new(max_keys: 2)
      limiter = bucket(small, capacity: 1)
      %w[a b c].each { |key| limiter.take(key) }
      expect(small.read("a")).to be_nil
      expect(small.read("c")).not_to be_nil
    end
  end

  context "with the database store" do
    let(:store) { RateLimiting::RecordStore.new }

    it_behaves_like "a bucket store"

    it "shares its state between limiters, as two processes would" do
      first = bucket(store, capacity: 2)
      second = bucket(RateLimiting::RecordStore.new, capacity: 2)
      expect([ first.take("k"), second.take("k"), first.take("k") ]).to eq([ true, true, false ])
      expect(RateBucket.where(key: "k").count).to eq(1)
    end
  end

  it "rejects settings that make no sense" do
    store = RateLimiting::MemoryStore.new
    expect { bucket(store, capacity: 0) }.to raise_error(ArgumentError)
    expect { bucket(store, per_second: -1) }.to raise_error(ArgumentError)
    never = bucket(store, capacity: 1, per_second: 0)
    never.take("k")
    expect(never.wait_time("k")).to eq(Float::INFINITY)
  end
end

RSpec.describe Notifications::Outbox do
  let(:clock) { Struct.new(:now).new(Time.utc(2025, 3, 3, 9)) }
  let(:limiter) do
    RateLimiting::TokenBucket.new(store: RateLimiting::MemoryStore.new, capacity: 2, refill_per_second: 0.5,
                                  clock: -> { clock.now })
  end

  before do
    5.times { |index| book(student, from: at(10 + index), to: at(11 + index), in_room: room(north, "Room #{index}")) }
  end

  def drain = in_north { described_class.drain(limiter:, now: clock.now) }
  def statuses = in_north { Delivery.order(:id).pluck(:status) }

  it "sends oldest first as far as the limit allows and keeps the rest queued" do
    result = drain
    expect(result).to have_attributes(sent: 2, remaining: 3, retry_in: 2.0)
    expect(statuses).to eq(%w[sent sent queued queued queued])
    in_north { expect(Delivery.where(status: "sent").pluck(:attempts, :sent_at)).to all(eq([ 1, clock.now ])) }
  end

  it "sends the rest later, and drops nothing" do
    drain
    clock.now += 4
    expect(drain).to have_attributes(sent: 2, remaining: 1)
    clock.now += 2
    expect(drain).to have_attributes(sent: 1, remaining: 0, retry_in: nil)
    expect(statuses).to all(eq("sent"))
  end

  it "limits each workspace separately" do
    drain
    book(south_admin, in_room: room(south, "South room"))
    result = Tenancy.with(south) { described_class.drain(limiter:, now: clock.now) }
    expect(result).to have_attributes(sent: 1, remaining: 0)
  end

  it "never sends a skipped delivery" do
    in_north { Delivery.order(:id).first.update!(status: "skipped") }
    clock.now += 60
    drain
    expect(statuses.first).to eq("skipped")
  end
end

RSpec.describe DeliveryJob do
  before { RateBucket.delete_all }

  it "sends what the limit allows and schedules itself again for the rest" do
    7.times { |index| book(student, from: at(10 + index), to: at(10 + index, 30), in_room: room(north, "Room #{index}")) }
    clear_enqueued_jobs

    expect { described_class.perform_now(north.id) }.to have_enqueued_job(described_class).with(north.id)
    in_north { expect(Delivery.group(:status).count).to eq("sent" => 5, "queued" => 2) }

    travel 10.seconds
    clear_enqueued_jobs
    expect { described_class.perform_now(north.id) }.not_to have_enqueued_job(described_class)
    in_north { expect(Delivery.queued.count).to eq(0) }
  end

  it "does nothing for a workspace that no longer exists" do
    expect { described_class.perform_now(0) }.not_to raise_error
  end
end

RSpec.describe Auth::SignIn do
  before { student }

  def sign_in(email: "mia@example.com", password: World::PASSWORD, attempts: described_class::ATTEMPTS)
    described_class.call(email:, password:, client_key: "1.2.3.4", attempts:)
  end

  it "returns the user and a session token for the right password" do
    signed_in, token, expires_at = sign_in(email: "  MIA@example.com ")
    expect(signed_in).to eq(student.user)
    expect(Session.find_user(token)).to eq(student.user)
    expect(expires_at).to eq(12.hours.from_now)
  end

  it "gives the same answer for a wrong password and an unknown email" do
    [ { password: "nope" }, { email: "ghost@example.com" } ].each do |attempt|
      expect { sign_in(**attempt) }.to raise_error(ApiError) { |error|
        expect([ error.code, error.message ]).to eq([ "UNAUTHENTICATED", "Email or password is wrong." ])
      }
    end
    expect(Session.count).to eq(0)
  end

  it "locks out repeated guesses for one address and email, even with the right password" do
    8.times { expect { sign_in(password: "guess") }.to raise_error(ApiError) }
    expect { sign_in }.to raise_error(ApiError) { |error| expect(error.code).to eq("RATE_LIMITED") }
    expect { sign_in(email: "sol@example.com") }.to raise_error(ApiError) { |error|
      expect(error.code).to eq("UNAUTHENTICATED")
    }
    travel 61.seconds
    expect(sign_in.first).to eq(student.user)
  end
end
