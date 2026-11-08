# One workspace is "current" for the length of a request or a job. Every model
# that includes TenantScoped reads and writes only that workspace's rows.
#
# The rule fails closed: if no workspace is set, a query on a tenant model raises
# instead of returning every workspace's data.
module Tenancy
  class NotSet < StandardError
    def initialize(msg = "No workspace is set. Wrap the work in Tenancy.with(workspace).")
      super
    end
  end

  module_function

  def with(workspace, membership: nil, &)
    raise ArgumentError, "a workspace is required" if workspace.nil?

    Current.set(workspace:, membership:, &)
  end

  def current
    Current.workspace
  end

  def current!
    Current.workspace || raise(NotSet)
  end
end
