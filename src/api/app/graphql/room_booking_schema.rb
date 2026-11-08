class RoomBookingSchema < GraphQL::Schema
  query Types::QueryType
  mutation Types::MutationType

  # Batches record lookups made while resolving one request (no N+1 queries).
  use GraphQL::Dataloader

  # Limits that stop a hostile query from being expensive.
  max_depth 12
  max_complexity 400
  default_max_page_size 50
  validate_max_errors 20

  # Expected failures reach the caller with a stable code in `extensions`.
  rescue_from(ApiError) do |error|
    raise GraphQL::ExecutionError.new(
      error.message, extensions: { "code" => error.code, "issues" => error.issues.map(&:to_h) }
    )
  end

  rescue_from(ActiveRecord::RecordInvalid) do |error|
    api_error = ApiError.from_record(error.record)
    raise GraphQL::ExecutionError.new(
      api_error.message, extensions: { "code" => api_error.code, "issues" => api_error.issues.map(&:to_h) }
    )
  end

  rescue_from(Tenancy::NotSet) do
    raise GraphQL::ExecutionError.new(
      "Choose a workspace first.", extensions: { "code" => "WORKSPACE_REQUIRED", "issues" => [] }
    )
  end
end
