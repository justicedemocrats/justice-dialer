defmodule Livevox.Session do
  use Agent
  defstruct [:id, :expires_at]

  def clientname, do: Application.get_env(:livevox, :clientname)
  def username, do: Application.get_env(:livevox, :username)
  def password, do: Application.get_env(:livevox, :password)

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
    # Clean up
    session_id =
      case Agent.get(__MODULE__, fn session -> session end) do
        # if needs updating, update and return
        %Livevox.Session{id: id, expires_at: expires_at} ->
          id

        nil ->
          new_session()
          session_id()
      end
  end

  defp create_session do
    %{body: %{"sessionId" => sessionId}} =
      Livevox.Api.post(
        "session/v5.0/login",
        headers: [no_session: true],
        body: %{userName: username, password: password, clientName: clientname}
      )

    %Livevox.Session{id: sessionId, expires_at: Timex.shift(Timex.now(), hours: 25)}
  end
end
