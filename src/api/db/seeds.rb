# Fictional demo data. Every name is invented and every address uses the
# reserved example.com domain. Bookings are made through the same code the API
# uses, so the rules and the notification log are real.
#
# Running this twice does nothing the second time.
return if Workspace.exists?

demo_password = "practice-demo"
person = ->(name, email) { User.create!(name:, email:, password: demo_password) }

larkfield = Workspace.create!(name: "Larkfield Music School", time_zone: "Europe/Lisbon",
                              status_labels: { "missed" => "No-show" })
harbour = Workspace.create!(name: "Harbour Street Rehearsal Rooms", time_zone: "Europe/Lisbon")

odile = person.call("Odile Marchetti", "odile@example.com")
bram = person.call("Bram Okonkwo", "bram@example.com")
suvi = person.call("Suvi Lahtinen", "suvi@example.com")
teo = person.call("Teo Almeida", "teo@example.com")
ines = person.call("Ines Duarte", "ines@example.com")

admin = larkfield.memberships.create!(user: odile, role: "admin")
staff = larkfield.memberships.create!(user: bram, role: "staff")
suvi_at_larkfield = larkfield.memberships.create!(user: suvi, role: "student", instrument: "Cello",
                                                  phone: "+351 555 0101")
# Teo has not given his details yet, so his first booking asks for them.
larkfield.memberships.create!(user: teo, role: "student")
harbour_admin = harbour.memberships.create!(user: ines, role: "admin")
harbour.memberships.create!(user: odile, role: "student", instrument: "Piano", phone: "+351 555 0102")

Tenancy.with(larkfield) do
  piano = Room.create!(name: "Room 1, upright piano", capacity: 2, equipment: [ "Upright piano", "Metronome" ])
  drums = Room.create!(name: "Room 2, drum kit", capacity: 3, equipment: [ "Drum kit", "Sound-proofing" ],
                       opens_minute: 10 * 60, closes_minute: 20 * 60)
  Room.create!(name: "Ensemble room", capacity: 12, equipment: [ "Grand piano", "Music stands", "Chairs" ])

  today = larkfield.zone.now.beginning_of_day
  at = ->(day, hour, minute = 0) { today + day.days + hour.hours + minute.minutes }
  long_ago = today - 30.days

  # Made "a month ago", so that bookings on past days pass the rules for staff
  # and students alike.
  as_staff = Bookings::Actions.new(staff, now: long_ago)
  as_suvi = Bookings::Actions.new(suvi_at_larkfield, now: long_ago)

  as_suvi.create(room_id: piano.id, starts_at: at.call(-1, 16), ends_at: at.call(-1, 17))
  as_suvi.create(room_id: piano.id, starts_at: at.call(0, 9), ends_at: at.call(0, 10), note: "Scales and the Bach suite")
  as_suvi.create(room_id: drums.id, starts_at: at.call(1, 14), ends_at: at.call(1, 15, 30))
  as_staff.create(room_id: piano.id, membership_id: admin.id, starts_at: at.call(0, 11), ends_at: at.call(0, 12, 30),
                  note: "Piano tuner visit")
  as_staff.create(room_id: piano.id, membership_id: suvi_at_larkfield.id, starts_at: at.call(2, 17),
                  ends_at: at.call(2, 18), notify: true)
  cancelled = as_staff.create(room_id: drums.id, membership_id: suvi_at_larkfield.id, starts_at: at.call(3, 10),
                              ends_at: at.call(3, 11))
  Bookings::Actions.new(staff, now: long_ago + 1.day)
                   .cancel(booking_id: cancelled.id, reason: "The drum kit is away for repair")

  NotificationTemplate.create!(
    kind: "confirmation",
    subject: "You are booked into {{room_name}}",
    body: "Hi {{student_name}},\n\nSee you on {{date}} at {{start_time}} in {{room_name}}. Please leave the " \
          "room as you found it by {{end_time}}.\n\n{{workspace_name}}\n\nStop these messages: {{unsubscribe_url}}"
  )

  Notifications::Outbox.drain
end

Tenancy.with(harbour) do
  studio = Room.create!(name: "Studio A", capacity: 6, equipment: [ "PA system" ])
  start = harbour.zone.now.beginning_of_day + 1.day + 18.hours
  Bookings::Actions.new(harbour_admin, now: start - 2.days)
                   .create(room_id: studio.id, starts_at: start, ends_at: start + 2.hours, note: "Band rehearsal")
end
