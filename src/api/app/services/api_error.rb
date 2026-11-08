# An error the caller is allowed to see, with a stable code the web app can act
# on. Anything else that is raised is a bug: it is logged, and the caller only
# learns that something went wrong.
class ApiError < StandardError
  Issue = Struct.new(:field, :message) do
    def to_h
      { "field" => field, "message" => message }
    end
  end

  attr_reader :code, :issues

  def initialize(code, message, issues: [])
    super(message)
    @code = code
    @issues = issues
  end

  def self.not_found(what) = new("NOT_FOUND", "#{what} not found.")
  def self.forbidden(message = "Your role does not allow this.") = new("FORBIDDEN", message)
  def self.conflict(message) = new("CONFLICT", message)
  def self.unauthenticated(message = "Sign in to continue.") = new("UNAUTHENTICATED", message)

  def self.invalid(message, issues = [])
    new("VALIDATION", message, issues:)
  end

  # Turns model validation errors into issues, keeping the attribute as the field.
  def self.from_record(record)
    issues = record.errors.map { |error| Issue.new(error.attribute.to_s.camelize(:lower), error.full_message) }
    invalid("Some of the input is not valid.", issues)
  end
end
