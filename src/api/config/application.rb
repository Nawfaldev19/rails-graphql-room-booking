require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"

Bundler.require(*Rails.groups)

module RoomBooking
  class Application < Rails::Application
    config.load_defaults 8.1
    config.autoload_lib(ignore: %w[tasks])
    config.api_only = true

    # Times are stored in UTC. Each workspace has its own time zone, applied
    # explicitly where wall-clock time matters (opening hours, weekly limits).
    config.time_zone = "UTC"

    # The Ruby schema format cannot express the triggers this app relies on, and
    # the SQL format needs the sqlite3 command-line tool to load. With a handful
    # of migrations, replaying them is instant, so no schema file is kept.
    config.active_record.dump_schema_after_migration = false

    # Hashed asset files are served straight from public/. The page itself goes
    # through PagesController, which marks it as never cached, so the static
    # file server must not answer "/" with public/index.html on its own.
    config.public_file_server.index_name = "not-served-as-an-index"

    # Cookies carry the session token. API-only apps leave this middleware out.
    config.middleware.use ActionDispatch::Cookies

    config.action_dispatch.default_headers.merge!(
      "Referrer-Policy" => "no-referrer",
      "Content-Security-Policy" =>
        "default-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; " \
        "frame-ancestors 'none'; base-uri 'self'; form-action 'self'"
    )

    config.x.public_url = ENV.fetch("PUBLIC_URL", "http://localhost:3400")
    config.x.session_ttl = ENV.fetch("SESSION_TTL_HOURS", "12").to_i.hours
    # Outgoing mail: a bucket of this many messages, refilled at this rate.
    config.x.mail_burst = ENV.fetch("MAIL_BURST", "5").to_i
    config.x.mail_per_second = ENV.fetch("MAIL_PER_SECOND", "1").to_f
  end
end
