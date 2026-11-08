# Per-request state. Rails resets it before and after every request and job.
class Current < ActiveSupport::CurrentAttributes
  attribute :workspace, :membership
end
