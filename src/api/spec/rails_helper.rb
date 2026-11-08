require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"

# There is no schema file (see config/application.rb), so the test database is
# brought up to date by running the migrations.
ActiveRecord::Migration.verbose = false
ActiveRecord::Base.connection_pool.migration_context.migrate

Rails.root.glob("spec/support/**/*.rb").sort.each { |file| require file }

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  config.include ActiveSupport::Testing::TimeHelpers
  config.include ActiveJob::TestHelper
  config.include World
  config.include GraphqlRequests, type: :request

  # Monday morning. The demo school is in Lisbon, which is on UTC in early March.
  config.before { travel_to Time.utc(2025, 3, 3, 9, 0) }
  config.after { Auth::SignIn::ATTEMPTS.instance_variable_get(:@store).clear }
end
