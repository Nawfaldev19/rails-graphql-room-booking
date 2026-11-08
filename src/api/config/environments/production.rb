require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.public_file_server.enabled = true
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.hour.to_i}" }

  # TLS is expected to end at a proxy in front of this server. Set FORCE_SSL=true
  # there so cookies are marked secure and plain HTTP is redirected.
  config.force_ssl = ENV["FORCE_SSL"] == "true"

  config.log_tags = [ :request_id ]
  config.logger = ActiveSupport::TaggedLogging.logger($stdout)
  config.log_level = ENV.fetch("LOG_LEVEL", "info")
  config.silence_healthcheck_path = "/healthz"
  config.active_support.report_deprecations = false
  config.active_job.queue_adapter = :async
  config.active_record.attributes_for_inspect = [ :id ]
end
