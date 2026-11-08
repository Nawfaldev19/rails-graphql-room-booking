module Types
  class QueryType < BaseObject
    field :viewer, ViewerType, description: "The signed-in user, or null."
    field :workspace, WorkspaceType, null: false,
                                     description: "The workspace named by the X-Workspace-Id header."
    field :notification_preferences, PreferencesType,
          null: false, description: "Public. What the holder of an unsubscribe link has switched on." do
      argument :token, String
    end

    def viewer = current_user

    def workspace
      actor!
      Tenancy.current!
    end

    def notification_preferences(token:)
      Mutations::UpdateNotificationPreferences.summary(token)
    end
  end
end
