# Include in every model whose rows belong to one workspace.
#
#   * Every query is limited to the current workspace by a default scope.
#   * New records are placed in the current workspace automatically.
#   * A record can never be saved into, or moved to, another workspace.
#
# `unscoped` would switch the first rule off. It is not used anywhere in the app,
# and a spec fails if it ever appears.
module TenantScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :workspace

    default_scope { where(workspace_id: Tenancy.current!.id) }

    before_validation(on: :create) { self.workspace ||= Tenancy.current! }
    validate :workspace_is_current
    attr_readonly :workspace_id
  end

  private

  def workspace_is_current
    return if workspace_id == Tenancy.current!.id

    errors.add(:workspace, "must be the current workspace")
  end
end
