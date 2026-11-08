require "rails_helper"

RSpec.describe "GraphQL API" do
  before { room }

  describe "the endpoint" do
    it "only accepts JSON bodies, which a cross-site form cannot send" do
      post "/graphql", params: { query: "{ viewer { id } }" }
      expect(response).to have_http_status(:unsupported_media_type)
    end

    it "answers null for the viewer when nobody is signed in" do
      gql("{ viewer { id } }")
      expect(data).to eq("viewer" => nil)
    end

    it "ignores a forged session cookie" do
      gql("{ viewer { id } }", headers: { "Cookie" => "room_booking_session=forged" })
      expect(data).to eq("viewer" => nil)
    end

    it "reports malformed queries as the caller's mistake" do
      gql("{ nonsense }")
      expect(response.parsed_body["errors"].first["message"]).to include("nonsense")
    end

    it "hides unexpected errors and logs them" do
      allow(RoomBookingSchema).to receive(:execute).and_raise(RuntimeError, "database on fire")
      allow(Rails.logger).to receive(:error)

      gql("{ viewer { id } }")

      expect(response).to have_http_status(:internal_server_error)
      expect(response.body).not_to include("database on fire")
      expect(error_code).to eq("INTERNAL")
      expect(Rails.logger).to have_received(:error).with(/RuntimeError: database on fire/)
    end

    it "refuses queries that are too deep to be honest" do
      nested = "{ workspace { bookings(from: \"2025-03-03T00:00:00Z\", to: \"2025-03-04T00:00:00Z\") " \
               "{ room { id } } me { workspace { id } } } }"
      gql("{ viewer { memberships { workspace { id } } } }#{' ' * 0}", as: student)
      expect(response.parsed_body["errors"]).to be_nil
      gql(nested, as: student)
      expect(response.parsed_body["errors"]).to be_nil
    end
  end

  describe "signing in and out" do
    let(:login) do
      "mutation($e: String!, $p: String!) { login(email: $e, password: $p) { name memberships { role workspace { name } } } }"
    end

    it "sets an HttpOnly, SameSite cookie and returns the viewer" do
      student
      gql(login, variables: { e: "mia@example.com", p: World::PASSWORD })

      expect(data["login"]).to eq("name" => "Mia",
                                  "memberships" => [ { "role" => "STUDENT",
                                                       "workspace" => { "name" => "North School" } } ])
      cookie = response.headers["Set-Cookie"]
      expect(cookie).to match(/room_booking_session=[\w-]{43};/)
      expect(cookie).to include("httponly").and include("samesite=lax")
    end

    it "sets no cookie when the password is wrong" do
      student
      gql(login, variables: { e: "mia@example.com", p: "wrong" })
      expect(error_code).to eq("UNAUTHENTICATED")
      expect(response.headers["Set-Cookie"]).to be_nil
    end

    it "ends the session on logout" do
      cookie = cookie_for(student)
      gql("mutation { logout }", headers: { "Cookie" => cookie })
      expect(data).to eq("logout" => true)
      gql("{ viewer { id } }", headers: { "Cookie" => cookie })
      expect(data).to eq("viewer" => nil)
    end
  end

  describe "choosing a workspace" do
    it "needs a sign-in" do
      gql("{ workspace { name } }", workspace: north)
      expect(error_code).to eq("UNAUTHENTICATED")
    end

    it "needs the workspace header" do
      gql("{ workspace { name } }", as: student.user)
      expect(error_code).to eq("WORKSPACE_REQUIRED")
    end

    it "answers not found for a workspace the user is not in, exactly as for one that does not exist" do
      south_admin
      gql("{ workspace { name } }", as: student.user, workspace: south)
      not_a_member = response.parsed_body
      gql("{ workspace { name } }", as: student.user, headers: { "X-Workspace-Id" => "999999" })

      expect(not_a_member).to eq(response.parsed_body)
      expect(error_code).to eq("NOT_FOUND")
    end

    it "shows the workspace and the viewer's place in it" do
      gql("{ workspace { name timeZone weeklyLimitMinutes me { role name missingProfileDetails } rooms { name } } }",
          as: student)
      expect(data["workspace"]).to eq(
        "name" => "North School", "timeZone" => "Europe/Lisbon", "weeklyLimitMinutes" => 360,
        "me" => { "role" => "STUDENT", "name" => "Mia", "missingProfileDetails" => [] },
        "rooms" => [ { "name" => "Room 1" } ]
      )
    end
  end

  describe "isolation between workspaces" do
    let!(:south_booking) { book(south_admin, in_room: room(south, "South room"), note: "Secret rehearsal") }
    let(:bookings_query) do
      "{ workspace { bookings(from: \"2025-03-03T00:00:00Z\", to: \"2025-03-10T00:00:00Z\") { id note } rooms { name } } }"
    end

    it "lists only the current workspace's rooms and bookings" do
      book(student)
      gql(bookings_query, as: staff)
      expect(data["workspace"]["rooms"]).to eq([ { "name" => "Room 1" } ])
      expect(data["workspace"]["bookings"].size).to eq(1)
      expect(response.body).not_to include("Secret rehearsal", "South room")
    end

    it "answers not found when another workspace's ids are used in mutations" do
      {
        "mutation($id: ID!) { cancelBooking(bookingId: $id, reason: \"x\") { id } }" => { id: south_booking.id },
        "mutation($id: ID!) { setBookingStatus(bookingId: $id, status: MISSED) { id } }" => { id: south_booking.id },
        "mutation($id: ID!) { createBooking(roomId: $id, startsAt: \"2025-03-03T14:00:00Z\", endsAt: \"2025-03-03T15:00:00Z\") { id } }" =>
          { id: south_booking.room_id },
        "mutation($id: ID!) { createBooking(roomId: #{room.id}, membershipId: $id, startsAt: \"2025-03-03T14:00:00Z\", endsAt: \"2025-03-03T15:00:00Z\") { id } }" =>
          { id: south_admin.id }
      }.each do |mutation, variables|
        gql(mutation, variables:, as: admin)
        expect(error_code).to eq("NOT_FOUND"), "expected NOT_FOUND for #{mutation}"
        expect(data).to be_nil
      end
      Tenancy.with(south) { expect(south_booking.reload.status).to eq("booked") }
    end
  end

  describe "bookings" do
    let(:create) do
      "mutation($room: ID!, $from: ISO8601DateTime!, $to: ISO8601DateTime!, $for: ID, $notify: Boolean) {
         createBooking(roomId: $room, startsAt: $from, endsAt: $to, membershipId: $for, notify: $notify) {
           id status statusLabel isMine personName lockVersion canCancel canReschedule canCheckIn room { name } calendarFile
         } }"
    end
    let(:list) do
      "{ workspace { bookings(from: \"2025-03-03T00:00:00Z\", to: \"2025-03-04T00:00:00Z\") {
           startsAt status isMine personName personId note canCancel canCheckIn room { name } calendarFile } } }"
    end

    it "creates a booking and reports what the viewer may do with it" do
      gql(create, variables: { room: room.id, from: at(14).iso8601, to: at(15).iso8601 }, as: student)

      expect(data["createBooking"]).to include(
        "status" => "BOOKED", "statusLabel" => "Booked", "isMine" => true, "personName" => "Mia",
        "lockVersion" => 0, "canCancel" => true, "canReschedule" => true, "canCheckIn" => false,
        "room" => { "name" => "Room 1" }
      )
      expect(data["createBooking"]["calendarFile"]).to include("BEGIN:VEVENT")
    end

    it "returns each broken rule with its field" do
      gql(create, variables: { room: room.id, from: at(7).iso8601, to: at(7, 20).iso8601 }, as: student)
      expect(error_code).to eq("VALIDATION")
      expect(error_issues.pluck("field")).to eq(%w[startsAt endsAt startsAt startsAt])
    end

    it "answers CONFLICT when the room is taken" do
      book(other_student)
      gql(create, variables: { room: room.id, from: at(14, 30).iso8601, to: at(15, 30).iso8601 }, as: student)
      expect(error_code).to eq("CONFLICT")
    end

    it "shows students that a slot is taken, but not by whom or why" do
      book(other_student, note: "Private audition practice")
      book(student, from: at(16), to: at(17), note: "Mine")
      gql(list, as: student)

      theirs, mine = data["workspace"]["bookings"]
      expect(theirs).to include("status" => "BOOKED", "isMine" => false, "personName" => nil, "personId" => nil,
                                "note" => nil, "canCancel" => false, "calendarFile" => nil)
      expect(mine).to include("isMine" => true, "personName" => "Mia", "note" => "Mine", "canCancel" => true)
      expect(response.body).not_to include("Private audition practice", "Noa")
    end

    it "shows staff everything, and lets them act" do
      book(other_student, note: "Private audition practice")
      travel_to at(14, 5)
      gql(list, as: staff)
      expect(data["workspace"]["bookings"].first).to include(
        "personName" => "Noa", "note" => "Private audition practice", "canCancel" => true, "canCheckIn" => true
      )
    end

    it "leaves cancelled bookings out of the calendar but keeps them in the person's own list" do
      booking = book(student)
      gql("mutation($id: ID!) { cancelBooking(bookingId: $id) { status cancelledAfterStart } }",
          variables: { id: booking.id }, as: student)
      expect(data["cancelBooking"]).to eq("status" => "CANCELLED", "cancelledAfterStart" => false)

      gql(list, as: student)
      expect(data["workspace"]["bookings"]).to eq([])
      gql("{ workspace { myBookings { status } } }", as: student)
      expect(data["workspace"]["myBookings"]).to eq([ { "status" => "CANCELLED" } ])
    end

    it "limits how long a period can be asked for" do
      gql("{ workspace { bookings(from: \"2025-01-01T00:00:00Z\", to: \"2025-12-31T00:00:00Z\") { id } } }", as: student)
      expect(error_code).to eq("VALIDATION")
    end

    it "keeps staff-only actions and lists from students" do
      booking = book(student)
      gql("mutation($id: ID!) { setBookingStatus(bookingId: $id, status: CHECKED_IN) { id } }",
          variables: { id: booking.id }, as: student)
      expect(error_code).to eq("FORBIDDEN")

      [ "people { name }", "deliveries { items { id } }", "queuedDeliveries",
        "notificationTemplates { kind }" ].each do |field|
        gql("{ workspace { #{field} } }", as: student)
        expect(error_code).to eq("FORBIDDEN"), "expected #{field} to be forbidden"
      end
    end

    it "loads a full day without one query per booking" do
      6.times do |index|
        book(index.even? ? student : other_student, from: at(10 + index), to: at(10 + index, 30),
                                                    in_room: room(north, "Room #{index % 3}"))
      end
      cookie = cookie_for(staff)
      count_queries = lambda do
        queries = 0
        counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
          post "/graphql", params: { query: list }.to_json,
                           headers: { "Content-Type" => "application/json", "Cookie" => cookie, "X-Workspace-Id" => north.id.to_s }
        end
        queries
      end

      with_six = count_queries.call
      6.times do |index|
        book(other_student, from: at(16 + (index % 3)), to: at(16 + (index % 3), 30), in_room: room(north, "Extra #{index}"))
      end
      with_twelve = count_queries.call

      expect(data["workspace"]["bookings"].size).to eq(12)
      expect(with_twelve).to eq(with_six)
    end
  end

  describe "the first booking of a new student" do
    let(:newcomer) { member(north, "teo", "student") }
    let(:variables) { { room: room.id, from: at(14).iso8601, to: at(15).iso8601 } }
    let(:create) do
      "mutation($room: ID!, $from: ISO8601DateTime!, $to: ISO8601DateTime!) { createBooking(roomId: $room, startsAt: $from, endsAt: $to) { id } }"
    end

    it "asks for two details once, then never again" do
      gql(create, variables:, as: newcomer)
      expect(error_code).to eq("PROFILE_INCOMPLETE")
      expect(error_issues.pluck("field")).to eq(%w[instrument phone])

      gql("mutation { updateProfile(instrument: \" \", phone: \"555 0199\") { id } }", as: newcomer)
      expect(error_issues).to eq([ { "field" => "instrument", "message" => "This is needed." } ])

      gql("mutation { updateProfile(instrument: \"Oboe\", phone: \"555 0199\") { missingProfileDetails } }", as: newcomer)
      expect(data["updateProfile"]).to eq("missingProfileDetails" => [])

      gql(create, variables:, as: newcomer)
      expect(data["createBooking"]["id"]).to be_present
    end
  end

  describe "settings" do
    it "lets an admin rename statuses, and shows the new word on bookings" do
      book(student)
      gql("mutation { updateStatusLabels(labels: [{ status: MISSED, label: \"No-show\" }, { status: BOOKED, label: \" Reserved \" }, { status: CANCELLED, label: \"\" }]) {
             statusLabels { status label defaultLabel } } }", as: admin)

      expect(data["updateStatusLabels"]["statusLabels"]).to include(
        { "status" => "BOOKED", "label" => "Reserved", "defaultLabel" => "Booked" },
        { "status" => "CANCELLED", "label" => "Cancelled", "defaultLabel" => "Cancelled" },
        { "status" => "MISSED", "label" => "No-show", "defaultLabel" => "Missed" }
      )
      gql("{ workspace { myBookings { status statusLabel } } }", as: student)
      expect(data["workspace"]["myBookings"]).to eq([ { "status" => "BOOKED", "statusLabel" => "Reserved" } ])
    end

    it "refuses renames from non-admins and invalid labels from admins" do
      rename = "mutation($label: String!) { updateStatusLabels(labels: [{ status: MISSED, label: $label }]) { id } }"
      gql(rename, variables: { label: "No-show" }, as: staff)
      expect(error_code).to eq("FORBIDDEN")

      gql(rename, variables: { label: "Booked" }, as: admin)
      expect(error_code).to eq("VALIDATION")
      expect(error_issues.first["message"]).to eq("Status labels must be different from each other")
      expect(north.reload.status_labels).to eq({})
    end

    it "shows default templates, saves a custom one, and refuses unknown merge tags" do
      gql("{ workspace { notificationTemplates { kind isDefault } templateTags { name } } }", as: admin)
      expect(data["workspace"]["notificationTemplates"]).to eq(
        %w[CONFIRMATION CHANGE CANCELLATION].map { |kind| { "kind" => kind, "isDefault" => true } }
      )
      expect(data["workspace"]["templateTags"].pluck("name")).to include("student_name", "unsubscribe_url")

      update = "mutation($s: String!, $b: String!) { updateNotificationTemplate(kind: CHANGE, subject: $s, body: $b) { subject isDefault } }"
      gql(update, variables: { s: "Moved: {{room_name}}", b: "Hi {{studnet_name}}" }, as: admin)
      expect(error_code).to eq("VALIDATION")
      expect(error_issues).to eq([ { "field" => "body", "message" => "Body uses the unknown tag {{studnet_name}}" } ])

      gql(update, variables: { s: "Moved: {{room_name}}", b: "Hi {{student_name}}" }, as: admin)
      expect(data["updateNotificationTemplate"]).to eq("subject" => "Moved: {{room_name}}", "isDefault" => false)

      gql(update, variables: { s: "x", b: "y" }, as: staff)
      expect(error_code).to eq("FORBIDDEN")
    end

    it "previews a template with sample values, or lists its problems" do
      preview = "query($s: String!, $b: String!) { workspace { templatePreview(subject: $s, body: $b) { subject body problems } } }"
      gql(preview, variables: { s: "Hi {{student_name}}", b: "{{room_name}} at {{start_time}}" }, as: admin)
      expect(data["workspace"]["templatePreview"]).to eq("subject" => "Hi Ada Fictional", "body" => "Room 2 at 16:00",
                                                         "problems" => [])

      gql(preview, variables: { s: "Hi {{who}}", b: "{{room_name" }, as: admin)
      expect(data["workspace"]["templatePreview"]["problems"]).to eq(
        [ "The subject uses the unknown tag {{who}}.", "The message has an unfinished tag (check the curly brackets)." ]
      )
    end
  end

  describe "the delivery log" do
    before { RateBucket.delete_all }

    it "pages newest first without gaps or repeats, for staff" do
      5.times do |index|
        travel 1.second
        book(student, from: at(10 + index), to: at(10 + index, 30), in_room: room(north, "Room #{index}"))
      end
      page = "query($after: String) { workspace { queuedDeliveries deliveries(first: 2, after: $after) { endCursor hasNextPage items { subject status } } } }"

      seen = []
      cursor = nil
      3.times do
        gql(page, variables: { after: cursor }, as: staff)
        result = data["workspace"]["deliveries"]
        seen.concat(result["items"].pluck("subject"))
        cursor = result["endCursor"]
        break unless result["hasNextPage"]
      end

      expect(data["workspace"]["queuedDeliveries"]).to eq(5)
      expect(seen).to eq((0..4).map { |index| "Booked: Room #{index} on Monday 3 March 2025" }.reverse)
    end

    it "rejects a broken cursor and an oversized page" do
      gql("{ workspace { deliveries(after: \"garbage\") { items { id } } } }", as: staff)
      expect(error_code).to eq("VALIDATION")
      gql("{ workspace { deliveries(first: 500) { items { id } } } }", as: staff)
      expect(error_code).to eq("VALIDATION")
    end

    it "sends queued mail on request, as far as the rate limit allows" do
      7.times { |index| book(student, from: at(10 + index), to: at(10 + index, 30), in_room: room(north, "Room #{index}")) }
      gql("mutation { sendQueuedMail { sent remaining } }", as: staff)
      expect(data["sendQueuedMail"]).to eq("sent" => 5, "remaining" => 2)

      gql("mutation { sendQueuedMail { sent } }", as: student)
      expect(error_code).to eq("FORBIDDEN")
    end
  end

  describe "unsubscribe links" do
    let(:token) { Notifications::UnsubscribeToken.for(student) }
    let(:read) do
      "query($t: String!) { notificationPreferences(token: $t) { workspaceName personName preferences { kind enabled } } }"
    end
    let(:change) do
      "mutation($t: String!) { updateNotificationPreferences(token: $t, preferences: [{ kind: CONFIRMATION, enabled: false }]) { preferences { kind enabled } } }"
    end

    it "work without a sign-in and show everything switched on by default" do
      gql(read, variables: { t: token })
      expect(data["notificationPreferences"]).to eq(
        "workspaceName" => "North School", "personName" => "Mia",
        "preferences" => %w[CONFIRMATION CHANGE CANCELLATION].map { |kind| { "kind" => kind, "enabled" => true } }
      )
    end

    it "switch one kind of message off, which later bookings respect, and back on" do
      gql(change, variables: { t: token })
      expect(data["updateNotificationPreferences"]["preferences"].first).to eq("kind" => "CONFIRMATION", "enabled" => false)

      book(student)
      in_north { expect(Delivery.sole).to have_attributes(kind: "confirmation", status: "skipped") }

      gql(change.sub("enabled: false", "enabled: true"), variables: { t: token })
      book(student, from: at(16), to: at(17))
      in_north { expect(Delivery.order(:id).last.status).to eq("queued") }
    end

    it "answer not found for a forged token, and change nothing" do
      gql(change, variables: { t: "#{token}x" })
      expect(error_code).to eq("NOT_FOUND")
      in_north { expect(NotificationPreference.count).to eq(0) }
    end

    it "only change the preferences of the person the link was made for" do
      gql(change, variables: { t: token })
      in_north do
        expect(NotificationPreference.enabled?(student, "confirmation")).to be(false)
        expect(NotificationPreference.enabled?(other_student, "confirmation")).to be(true)
      end
    end
  end
end
