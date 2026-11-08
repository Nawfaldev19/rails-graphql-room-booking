require "rails_helper"

RSpec.describe Notifications::TemplateRenderer do
  let(:values) { described_class.sample_values(north) }

  it "fills known tags, with or without spaces inside the brackets" do
    expect(described_class.render("Hi {{student_name}}, see you in {{ room_name }}.", values))
      .to eq("Hi Ada Fictional, see you in Room 2.")
  end

  it "leaves text without tags alone" do
    expect(described_class.render("No tags here. 100% plain {text}.", values)).to eq("No tags here. 100% plain {text}.")
  end

  it "names unknown tags and unfinished brackets" do
    expect(described_class.problems("Hi {{studnet_name}} and {{nope}} and {{studnet_name}}"))
      .to eq([ "uses the unknown tag {{studnet_name}}", "uses the unknown tag {{nope}}" ])
    expect(described_class.problems("Hi {{student_name")).to eq([ "has an unfinished tag (check the curly brackets)" ])
    expect(described_class.problems("Hi student_name}}")).to eq([ "has an unfinished tag (check the curly brackets)" ])
    expect(described_class.problems("Hi {{student_name}}")).to eq([])
  end

  it "refuses to render a template that has problems" do
    expect { described_class.render("{{password}}", values) }
      .to raise_error(described_class::UnknownTag, "uses the unknown tag {{password}}")
  end

  it "has a sample value and a description for every tag" do
    expect(values.keys).to match_array(described_class::TAGS.keys)
    expect(described_class::TAGS.values).to all(be_present)
  end

  it "takes real values from a booking, in the school's time zone and words" do
    north.update!(status_labels: { "booked" => "Reserved" })
    travel_to Time.utc(2025, 3, 28, 9, 0)
    booking = book(student, from: Time.utc(2025, 3, 31, 13, 0), to: Time.utc(2025, 3, 31, 14, 30))
    values = in_north { described_class.values_for(booking, unsubscribe_url: "https://example.com/u") }

    expect(values).to include(
      "student_name" => "Mia", "room_name" => "Room 1", "date" => "Monday 31 March 2025",
      "start_time" => "14:00", "end_time" => "15:30", "status" => "Reserved",
      "reason" => "No reason was given", "workspace_name" => "North School"
    )
  end

  it "keeps every default template free of problems" do
    Notifications::Defaults::TEMPLATES.each_value do |wording|
      expect(described_class.problems(wording[:subject]) + described_class.problems(wording[:body])).to eq([])
    end
  end
end

RSpec.describe Notifications::CalendarFile do
  let(:booking) { book(student, from: at(14), to: at(15, 30)) }
  let(:file) { in_north { described_class.build(booking, now: at(9)) } }
  let(:lines) { file.split("\r\n") }

  it "is a calendar with one event, with times in UTC" do
    expect(lines.first).to eq("BEGIN:VCALENDAR")
    expect(lines.last).to eq("END:VCALENDAR")
    expect(lines).to include(
      "VERSION:2.0", "METHOD:REQUEST", "UID:booking-#{booking.id}@room-booking.example", "SEQUENCE:0",
      "DTSTAMP:20250303T090000Z", "DTSTART:20250303T140000Z", "DTEND:20250303T153000Z",
      "SUMMARY:Room 1 (North School)", "LOCATION:Room 1", "STATUS:CONFIRMED"
    )
    expect(lines.count("BEGIN:VEVENT")).to eq(1)
  end

  it "ends every line with CRLF, as the format requires" do
    expect(file).to end_with("END:VCALENDAR\r\n")
    expect(file.gsub("\r\n", "")).not_to include("\n")
  end

  it "says so when the booking is cancelled, with the same identifier" do
    cancelled = in_north { described_class.build(booking, cancelled: true) }
    expect(cancelled).to include("METHOD:CANCEL", "STATUS:CANCELLED", "UID:booking-#{booking.id}@room-booking.example")
  end

  it "raises the sequence number when the booking changes, so calendars replace the old entry" do
    in_north do
      Bookings::Actions.new(student).reschedule(booking_id: booking.id, room_id: booking.room_id,
                                                starts_at: at(16), ends_at: at(17), lock_version: 0)
      expect(described_class.build(booking.reload)).to include("SEQUENCE:1", "DTSTART:20250303T160000Z")
    end
  end

  it "escapes the characters that have a meaning in the format" do
    expect(described_class.escape("Room 1, upright; back\\slash\nnext")).to eq("Room 1\\, upright; back\\\\slash\\nnext")
  end

  it "folds long lines at 75 octets without cutting a character in half" do
    long = "SUMMARY:#{'Ensaio de música de câmara ' * 6}"
    folded = described_class.fold(long)

    expect(folded.size).to be > 1
    expect(folded).to all(satisfy { |line| line.bytesize <= 75 })
    expect(folded.drop(1)).to all(start_with(" "))
    expect(folded.first + folded.drop(1).map { |line| line.delete_prefix(" ") }.join).to eq(long)
    expect(folded.join).to be_valid_encoding
    expect(described_class.fold("SHORT:line")).to eq([ "SHORT:line" ])
  end
end

RSpec.describe Notifications::UnsubscribeToken do
  it "round-trips a membership and builds a link from it" do
    token = described_class.for(student)
    expect(described_class.membership(token)).to eq(student)
    expect(described_class.url_for(student)).to start_with("http://localhost:3400/preferences/")
  end

  it "rejects forged, altered and unrelated tokens" do
    token = described_class.for(student)
    other_purpose = Rails.application.message_verifier("unsubscribe").generate(student.id, purpose: :login)

    expect(described_class.membership("#{token}x")).to be_nil
    expect(described_class.membership(student.id.to_s)).to be_nil
    expect(described_class.membership("")).to be_nil
    expect(described_class.membership(nil)).to be_nil
    expect(described_class.membership(other_purpose)).to be_nil
  end

  it "keeps working over time, because old emails must still unsubscribe" do
    token = described_class.for(student)
    travel 3.years
    expect(described_class.membership(token)).to eq(student)
  end
end

RSpec.describe Notifications::Dispatcher do
  let!(:booking) { book(student, from: at(14), to: at(15), notify: false) }

  def dispatch(kind = "confirmation")
    in_north { described_class.booking_event(booking, kind) }
  end

  before { in_north { Delivery.delete_all } }

  it "writes a queued delivery with the default wording and queues the sending job" do
    delivery = nil
    expect { delivery = dispatch }.to have_enqueued_job(DeliveryJob).with(north.id)
    expect(delivery).to have_attributes(status: "queued", kind: "confirmation", attempts: 0, skip_reason: nil)
    expect(delivery.body).to include("Hello Mia,", "Room 1 is yours on Monday 3 March 2025 from 14:00 to 15:00")
    expect(delivery.body).to match(%r{To stop these messages: http://localhost:3400/preferences/\S+})
  end

  it "uses the school's own template when there is one" do
    in_north do
      NotificationTemplate.create!(kind: "confirmation", subject: "Yours: {{room_name}}", body: "See you, {{student_name}}.")
    end
    expect(dispatch).to have_attributes(subject: "Yours: Room 1", body: "See you, Mia.")
  end

  it "logs the message as skipped, and sends nothing, when the person turned that kind off" do
    in_north { NotificationPreference.create!(membership: student, kind: "confirmation", enabled: false) }

    delivery = nil
    expect { delivery = dispatch }.not_to have_enqueued_job(DeliveryJob)
    expect(delivery).to have_attributes(status: "skipped", skip_reason: "The person turned these messages off.")
    expect(dispatch("change").status).to eq("queued")
  end

  it "puts a working unsubscribe link into the message" do
    token = dispatch.body[%r{/preferences/(\S+)}, 1]
    expect(Notifications::UnsubscribeToken.membership(token)).to eq(student)
  end
end

RSpec.describe NotificationTemplate do
  it "cannot be saved with an unknown merge tag or an unfinished one" do
    in_north do
      template = described_class.new(kind: "change", subject: "Hi {{nobody}}", body: "Dear {{student_name")
      expect(template).not_to be_valid
      expect(template.errors.full_messages).to eq(
        [ "Subject uses the unknown tag {{nobody}}", "Body has an unfinished tag (check the curly brackets)" ]
      )
      expect(described_class.new(kind: "reminder", subject: "x", body: "y")).not_to be_valid
    end
  end
end
