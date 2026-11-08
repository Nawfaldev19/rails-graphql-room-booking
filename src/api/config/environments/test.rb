Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = ENV["CI"].present?
  config.consider_all_requests_local = true
  config.cache_store = :null_store
  config.action_dispatch.show_exceptions = :rescuable
  config.active_support.deprecation = :stderr
  # Jobs run only when a test asks for them, so delivery timing can be tested.
  config.active_job.queue_adapter = :test
  config.public_file_server.enabled = true
end
