module Notifications
  # Fills merge tags such as {{student_name}} into a template.
  #
  # It is strict on purpose: a tag it does not know is a problem to be fixed when
  # the template is saved, not text to be mailed to people as "{{studnet_name}}".
  class TemplateRenderer
    TAGS = {
      "student_name" => "The name of the person the booking is for",
      "room_name" => "The room",
      "date" => "The day of the booking, in the school's time zone",
      "start_time" => "When it starts",
      "end_time" => "When it ends",
      "status" => "The booking's status, in the school's own words",
      "reason" => "The reason given for a cancellation",
      "workspace_name" => "The school's name",
      "unsubscribe_url" => "A link for turning these messages off"
    }.freeze
    TAG = /\{\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}\}/

    class UnknownTag < StandardError; end

    # Everything that is wrong with a template, as sentences. Empty when fine.
    def self.problems(text)
      found = text.scan(TAG).flatten.uniq.reject { |name| TAGS.key?(name) }
                  .map { |name| "uses the unknown tag {{#{name}}}" }
      leftover = text.gsub(TAG, "")
      found << "has an unfinished tag (check the curly brackets)" if leftover.include?("{{") || leftover.include?("}}")
      found
    end

    def self.render(text, values)
      issues = problems(text)
      raise UnknownTag, issues.join("; ") if issues.any?

      text.gsub(TAG) { values.fetch(Regexp.last_match(1)).to_s }
    end

    def self.values_for(booking, unsubscribe_url:)
      workspace = booking.workspace
      zone = workspace.zone
      {
        "student_name" => booking.membership.user.name,
        "room_name" => booking.room.name,
        "date" => booking.starts_at.in_time_zone(zone).strftime("%A %-d %B %Y"),
        "start_time" => booking.starts_at.in_time_zone(zone).strftime("%H:%M"),
        "end_time" => booking.ends_at.in_time_zone(zone).strftime("%H:%M"),
        "status" => workspace.status_label(booking.status),
        "reason" => booking.cancel_reason.presence || "No reason was given",
        "workspace_name" => workspace.name,
        "unsubscribe_url" => unsubscribe_url
      }
    end

    # Believable values for the live preview in the template editor.
    def self.sample_values(workspace)
      {
        "student_name" => "Ada Fictional",
        "room_name" => "Room 2",
        "date" => "Monday 3 March 2025",
        "start_time" => "16:00",
        "end_time" => "17:00",
        "status" => workspace.status_label("booked"),
        "reason" => "The piano is being tuned",
        "workspace_name" => workspace.name,
        "unsubscribe_url" => "#{Rails.configuration.x.public_url}/preferences/sample-link"
      }
    end
  end
end
