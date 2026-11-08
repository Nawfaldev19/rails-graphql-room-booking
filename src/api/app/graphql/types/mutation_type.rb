module Types
  class MutationType < BaseObject
    field :login, mutation: Mutations::Login
    field :logout, mutation: Mutations::Logout
    field :update_profile, mutation: Mutations::UpdateProfile
    field :create_booking, mutation: Mutations::CreateBooking
    field :reschedule_booking, mutation: Mutations::RescheduleBooking
    field :cancel_booking, mutation: Mutations::CancelBooking
    field :set_booking_status, mutation: Mutations::SetBookingStatus
    field :update_status_labels, mutation: Mutations::UpdateStatusLabels
    field :update_notification_template, mutation: Mutations::UpdateNotificationTemplate
    field :send_queued_mail, mutation: Mutations::SendQueuedMail
    field :update_notification_preferences, mutation: Mutations::UpdateNotificationPreferences
  end
end
