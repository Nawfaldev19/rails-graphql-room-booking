module Mutations
  class UpdateProfile < BaseMutation
    description "Saves the two details a student gives before a first booking."

    argument :instrument, String
    argument :phone, String
    type Types::MembershipType

    def resolve(instrument:, phone:)
      actor = actor!
      issues = { "instrument" => instrument, "phone" => phone }.filter_map do |field, value|
        ApiError::Issue.new(field, "This is needed.") if value.strip.empty?
      end
      raise ApiError.invalid("Both details are needed.", issues) if issues.any?

      actor.update!(instrument: instrument.strip, phone: phone.strip)
      actor
    end
  end
end
