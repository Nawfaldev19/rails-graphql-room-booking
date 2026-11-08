# Parameters whose names contain these fragments are replaced with [FILTERED]
# in the log. GraphQL variables are logged by name only (see GraphqlController).
Rails.application.config.filter_parameters += %i[
  passw email secret token _key crypt salt phone
]
