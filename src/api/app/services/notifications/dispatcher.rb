module Notifications
  # Decides whether a booking event becomes a message, writes it to the delivery
  # log either way, and queues the sending.
  class Dispatcher
    def self.booking_event(booking, kind)
      person = booking.membership
      template = NotificationTemplate.find_by(kind:)
      wording = template ? { subject: template.subject, body: template.body } : Defaults.for(kind)
      values = TemplateRenderer.values_for(booking, unsubscribe_url: UnsubscribeToken.url_for(person))
      wanted = NotificationPreference.enabled?(person, kind)

      delivery = Delivery.create!(
        membership: person,
        booking:,
        kind:,
        to_email: person.user.email,
        subject: TemplateRenderer.render(wording[:subject], values),
        body: TemplateRenderer.render(wording[:body], values),
        calendar_file: CalendarFile.build(booking, cancelled: kind == "cancellation"),
        # An unwanted message is still logged, as skipped, so staff can see why
        # someone did not hear about a change.
        status: wanted ? "queued" : "skipped",
        skip_reason: wanted ? nil : "The person turned these messages off."
      )
      DeliveryJob.perform_later(booking.workspace_id) if wanted
      delivery
    end
  end
end
