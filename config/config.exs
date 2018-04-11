# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Configures the endpoint
config :justice_dialer, JusticeDialer.Endpoint,
  url: [host: 'localhost'],
  secret_key_base: "GxtfaDIKOkay5x2k0cxuJYQPX4BEyeo9fHynynmVqtiJoDgZqM8gvXT8dSMXekhI",
  render_errors: [view: JusticeDialer.ErrorView, accepts: ~w(html json)],
  pubsub: [name: JusticeDialer.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Quantum config
config :justice_dialer, JusticeDialer.Scheduler,
  timezone: "America/New_York",
  jobs: [
    {"*/7 * * * *", {JusticeDialer.LoginConfig, :update, []}},
    {"0 5 * * *", {JusticeDialer.Logins, :reset, []}}
  ]

config :justice_dialer, ak_agent_report_page: 869

config :cosmic, slug: "brand-new-congress"

config :logger, backends: [:console, Rollbax.Logger]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
