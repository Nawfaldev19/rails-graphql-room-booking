if ENV["COVERAGE"] != "false"
  require "simplecov"
  SimpleCov.start do
    enable_coverage :branch
    skip "/spec/"
    skip "/config/"
    skip "/db/"
    skip "/vendor/"
    group "Models", "app/models"
    group "Services", "app/services"
    group "GraphQL", "app/graphql"
    group "Controllers and jobs", %w[app/controllers app/jobs]
    minimum_coverage line: 90, branch: 75
  end
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
