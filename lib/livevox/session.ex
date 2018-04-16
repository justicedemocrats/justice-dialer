defmodule Livevox.Session do
  use Agent
  defstruct [:id, :expires_at]
  require Logger

  def clientname, do: Application.get_env(:justice_dialer, :livevox_clientname)
  def username, do: Application.get_env(:justice_dialer, :livevox_username)
  def password, do: Application.get_env(:justice_dialer, :livevox_password)

  # State takes the format index
  def start_link do
    Agent.start_link(
      fn ->
        create_session()
      end,
      name: __MODULE__
    )
  end

  def new_session do
    session = create_session()
    Agent.update(__MODULE__, fn _state -> session end)
  end

  def session_id do
    case Agent.get(__MODULE__, fn session -> session end) do
      %Livevox.Session{id: id, expires_at: expires_at} ->
        if Timex.before?(expires_at, Timex.now()) do
          new_session()
          session_id()
        else
          id
        end

      nil ->
        IO.puts("Initiating session")
        new_session()
        session_id()
    end
  end

  defp create_session do
    %{body: %{"sessionId" => sessionId}} =
      Livevox.Api.post(
        "session/v6.0/login",
        headers: [no_session: true],
        body: %{userName: username, password: password, clientName: clientname}
      )

    %Livevox.Session{id: sessionId, expires_at: Timex.now() |> Timex.shift(hours: 24)}
  end
end
