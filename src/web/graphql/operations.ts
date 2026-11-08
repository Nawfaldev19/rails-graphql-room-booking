import { graphql } from './tada';

export const BookingParts = graphql(`
  fragment BookingParts on Booking @_unmask {
    id
    startsAt
    endsAt
    status
    statusLabel
    lockVersion
    isMine
    personId
    personName
    note
    cancelReason
    cancelledAfterStart
    canReschedule
    canCancel
    canCheckIn
    canMarkMissed
    room {
      id
      name
    }
  }
`);

export const ViewerQuery = graphql(`
  query Viewer {
    viewer {
      id
      name
      email
      memberships {
        id
        role
        workspace {
          id
          name
          timeZone
        }
      }
    }
  }
`);

export const LoginMutation = graphql(`
  mutation Login($email: String!, $password: String!) {
    login(email: $email, password: $password) {
      id
    }
  }
`);

export const LogoutMutation = graphql(`
  mutation Logout {
    logout
  }
`);

export const CalendarQuery = graphql(
  `
    query Calendar($from: ISO8601DateTime!, $to: ISO8601DateTime!) {
      workspace {
        id
        timeZone
        weeklyLimitMinutes
        me {
          id
          role
          missingProfileDetails
        }
        rooms {
          id
          name
          capacity
          opensMinute
          closesMinute
          equipment
        }
        bookings(from: $from, to: $to) {
          ...BookingParts
        }
      }
    }
  `,
  [BookingParts],
);

export const PeopleQuery = graphql(`
  query People {
    workspace {
      id
      people {
        id
        name
        role
      }
    }
  }
`);

export const MyBookingsQuery = graphql(
  `
    query MyBookings {
      workspace {
        id
        timeZone
        myBookings {
          ...BookingParts
          calendarFile
        }
      }
    }
  `,
  [BookingParts],
);

export const CreateBookingMutation = graphql(`
  mutation CreateBooking(
    $roomId: ID!
    $startsAt: ISO8601DateTime!
    $endsAt: ISO8601DateTime!
    $membershipId: ID
    $note: String
    $notify: Boolean
  ) {
    createBooking(
      roomId: $roomId
      startsAt: $startsAt
      endsAt: $endsAt
      membershipId: $membershipId
      note: $note
      notify: $notify
    ) {
      id
    }
  }
`);

export const RescheduleBookingMutation = graphql(`
  mutation RescheduleBooking(
    $bookingId: ID!
    $roomId: ID!
    $startsAt: ISO8601DateTime!
    $endsAt: ISO8601DateTime!
    $lockVersion: Int!
    $notify: Boolean
  ) {
    rescheduleBooking(
      bookingId: $bookingId
      roomId: $roomId
      startsAt: $startsAt
      endsAt: $endsAt
      lockVersion: $lockVersion
      notify: $notify
    ) {
      id
    }
  }
`);

export const CancelBookingMutation = graphql(`
  mutation CancelBooking($bookingId: ID!, $reason: String, $notify: Boolean) {
    cancelBooking(bookingId: $bookingId, reason: $reason, notify: $notify) {
      id
    }
  }
`);

export const SetBookingStatusMutation = graphql(`
  mutation SetBookingStatus($bookingId: ID!, $status: BookingStatusEnum!) {
    setBookingStatus(bookingId: $bookingId, status: $status) {
      id
    }
  }
`);

export const UpdateProfileMutation = graphql(`
  mutation UpdateProfile($instrument: String!, $phone: String!) {
    updateProfile(instrument: $instrument, phone: $phone) {
      id
      missingProfileDetails
    }
  }
`);

export const SettingsQuery = graphql(`
  query Settings {
    workspace {
      id
      name
      statusLabels {
        status
        label
        defaultLabel
      }
      notificationTemplates {
        kind
        subject
        body
        isDefault
      }
      templateTags {
        name
        description
      }
    }
  }
`);

export const TemplatePreviewQuery = graphql(`
  query TemplatePreview($subject: String!, $body: String!) {
    workspace {
      id
      templatePreview(subject: $subject, body: $body) {
        subject
        body
        problems
      }
    }
  }
`);

export const UpdateStatusLabelsMutation = graphql(`
  mutation UpdateStatusLabels($labels: [StatusLabelInput!]!) {
    updateStatusLabels(labels: $labels) {
      id
      statusLabels {
        status
        label
        defaultLabel
      }
    }
  }
`);

export const UpdateTemplateMutation = graphql(`
  mutation UpdateTemplate($kind: NotificationKindEnum!, $subject: String!, $body: String!) {
    updateNotificationTemplate(kind: $kind, subject: $subject, body: $body) {
      kind
      subject
      body
      isDefault
    }
  }
`);

export const OutboxQuery = graphql(`
  query Outbox($after: String) {
    workspace {
      id
      queuedDeliveries
      deliveries(first: 20, after: $after) {
        endCursor
        hasNextPage
        items {
          id
          kind
          toEmail
          subject
          body
          calendarFile
          status
          skipReason
          createdAt
          sentAt
        }
      }
    }
  }
`);

export const SendQueuedMailMutation = graphql(`
  mutation SendQueuedMail {
    sendQueuedMail {
      sent
      remaining
    }
  }
`);

export const PreferencesQuery = graphql(`
  query Preferences($token: String!) {
    notificationPreferences(token: $token) {
      workspaceName
      personName
      preferences {
        kind
        enabled
      }
    }
  }
`);

export const UpdatePreferencesMutation = graphql(`
  mutation UpdatePreferences($token: String!, $preferences: [PreferenceInput!]!) {
    updateNotificationPreferences(token: $token, preferences: $preferences) {
      preferences {
        kind
        enabled
      }
    }
  }
`);
