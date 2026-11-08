module Mutations
  class UpdateStatusLabels < BaseMutation
    description "Admins only. Renames statuses for this workspace. Behaviour does not change."

    argument :labels, [ StatusLabelInput ]
    type Types::WorkspaceType

    def resolve(labels:)
      admin!
      workspace = Tenancy.current!
      renamed = labels.to_h { |entry| [ entry.status, entry.label.strip ] }.reject { |_, label| label.empty? }
      workspace.update!(status_labels: renamed)
      workspace
    end
  end
end
