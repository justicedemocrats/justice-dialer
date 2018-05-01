defmodule JusticeDialer do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    # Define workers and child supervisors to be supervised
    children = [
      # Start the Ecto repository
      # can be readded when we have a database

      # Start the endpoint when the application starts
      supervisor(JusticeDialer.Endpoint, []),
      supervisor(Phoenix.PubSub.PG2, [:justice_dialer, []]),
      worker(Cosmic, [[application: :justice_dialer]]),
      worker(JusticeDialer.Scheduler, []),
      worker(Ak.List, []),
      worker(Ak.Signup, []),
      worker(Ak.Petition, []),
      worker(Livevox.Session, []),
      worker(Mongo, [
        [
          name: :mongo,
          database: "livevox",
          username: Application.get_env(:justice_dialer, :mongodb_username),
          password: Application.get_env(:justice_dialer, :mongodb_password),
          seeds: Application.get_env(:justice_dialer, :mongodb_seeds),
          port: Application.get_env(:justice_dialer, :mongodb_port)
        ]
      ]),
      worker(JusticeDialer.TwoFactor, []),
      worker(JusticeDialer.TwoFactorToken, []),
      worker(JusticeDialer.LoginConfig, []),
      worker(JusticeDialer.CampaignConfig, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: JusticeDialer.Supervisor]
    result = Supervisor.start_link(children, opts)

    result
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    JusticeDialer.Endpoint.config_change(changed, removed)
    :ok
  end
end
