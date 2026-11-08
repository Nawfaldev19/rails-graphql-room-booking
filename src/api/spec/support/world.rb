# Builders for the two workspaces most specs need:
#   north: an admin, a staff member, two students, two rooms
#   south: an admin and one room, to try to reach from north
module World
  PASSWORD = "correct horse battery staple".freeze

  def north
    @north ||= Workspace.create!(name: "North School", time_zone: "Europe/Lisbon")
  end

  def south
    @south ||= Workspace.create!(name: "South School", time_zone: "Europe/Lisbon")
  end

  def user(name)
    @users ||= {}
    @users[name] ||= User.create!(name: name.capitalize, email: "#{name}@example.com", password: PASSWORD)
  end

  def member(workspace, name, role, **details)
    @members ||= {}
    @members[[ workspace.id, name ]] ||=
      workspace.memberships.create!(user: user(name), role:, **details)
  end

  def admin = member(north, "ada", "admin")
  def staff = member(north, "sol", "staff")
  def student = member(north, "mia", "student", instrument: "Cello", phone: "555 0100")
  def other_student = member(north, "noa", "student", instrument: "Flute", phone: "555 0101")
  def south_admin = member(south, "zed", "admin")

  def room(workspace = north, name = "Room 1", **attributes)
    @rooms ||= {}
    @rooms[[ workspace.id, name ]] ||= Tenancy.with(workspace) { Room.create!(name:, **attributes) }
  end

  # A time on the Monday the suite is frozen at, or `day` days later, in UTC.
  def at(hour, minute = 0, day: 0)
    Time.utc(2025, 3, 3 + day, hour, minute)
  end

  def book(actor = student, from: at(14), to: at(15), in_room: nil, **options)
    in_room ||= room(actor.workspace)
    Tenancy.with(actor.workspace) do
      Bookings::Actions.new(actor).create(room_id: in_room.id, starts_at: from, ends_at: to, **options)
    end
  end

  def in_north(&) = Tenancy.with(north, &)
end
