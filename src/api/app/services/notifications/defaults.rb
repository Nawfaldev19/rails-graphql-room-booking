module Notifications
  # The wording used until a school writes its own.
  module Defaults
    FOOTER = "\n\nTo stop these messages: {{unsubscribe_url}}".freeze

    TEMPLATES = {
      "confirmation" => {
        subject: "Booked: {{room_name}} on {{date}}",
        body: "Hello {{student_name}},\n\n{{room_name}} is yours on {{date}} from {{start_time}} to " \
              "{{end_time}}. The calendar file is attached.\n\n{{workspace_name}}#{FOOTER}"
      },
      "change" => {
        subject: "Changed: your booking is now {{room_name}} on {{date}}",
        body: "Hello {{student_name}},\n\nYour booking was changed. It is now {{room_name}} on {{date}} " \
              "from {{start_time}} to {{end_time}}. The attached calendar file replaces the old one.\n\n" \
              "{{workspace_name}}#{FOOTER}"
      },
      "cancellation" => {
        subject: "Cancelled: {{room_name}} on {{date}}",
        body: "Hello {{student_name}},\n\nYour booking of {{room_name}} on {{date}} from {{start_time}} to " \
              "{{end_time}} was cancelled.\nReason: {{reason}}\n\n{{workspace_name}}#{FOOTER}"
      }
    }.freeze

    def self.for(kind) = TEMPLATES.fetch(kind)
  end
end
