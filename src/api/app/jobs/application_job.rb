class ApplicationJob < ActiveJob::Base
  # A job whose record has been removed in the meantime has nothing left to do.
  discard_on ActiveJob::DeserializationError
end
