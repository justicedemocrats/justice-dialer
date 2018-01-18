use Mix.Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with brunch.io to recompile .js and .css sources.
config :justice_dialer, JusticeDialer.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [npm: ["run", "watch", cd: Path.expand("../", __DIR__)]]

# Use Mailgun
config :justice_dialer, JusticeDialer.Mailer,
  adapter: Swoosh.Adapters.Mailgun,
  api_key: System.get_env("MAILGUN_KEY"),
  domain: System.get_env("MAILGUN_DOMAIN")

# Update secret
config :justice_dialer, update_secret: System.get_env("UPDATE_SECRET")

config :actionkit,
  base: System.get_env("AK_BASE"),
  username: System.get_env("AK_USERNAME"),
  password: System.get_env("AK_PASSWORD")

config :justice_dialer,
  mongodb_username: System.get_env("MONGO_USERNAME"),
  mongodb_hostname: System.get_env("MONGO_HOSTNAME"),
  mongodb_password: System.get_env("MONGO_PASSWORD"),
  mongodb_port: System.get_env("MONGO_PORT")

config :rollbax,
  access_token: System.get_env("ROLLBAR_ACCESS_TOKEN"),
  environment: "production"

config :rollbax, enabled: false