module Mutations
  class UpdateNotificationPreferences < BaseMutation
    description "Public. Changes which messages the holder of an unsubscribe link receives."

    argument :token, String
    argument :preferences, [ PreferenceInput ]
    type Types::PreferencesType

    def resolve(token:, preferences:)
      membership = self.class.membership!(token)
      Tenancy.with(membership.workspace) do
        preferences.each do |entry|
          NotificationPreference.find_or_initialize_by(membership:, kind: entry.kind)
                                .update!(enabled: entry.enabled)
        end
      end
      self.class.summary(token)
    end

    def self.membership!(token)
      Notifications::UnsubscribeToken.membership(token) || raise(ApiError.not_found("This link"))
    end

    def self.summary(token)
      membership = membership!(token)
      Tenancy.with(membership.workspace) do
        {
          workspace_name: membership.workspace.name,
          person_name: membership.user.name,
          preferences: NotificationTemplate::KINDS.map do |kind|
            { kind:, enabled: NotificationPreference.enabled?(membership, kind) }
          end
        }
      end
    end
  end
end
