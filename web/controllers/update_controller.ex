defmodule JusticeDialer.UpdateController do
  use JusticeDialer.Web, :controller
  alias Phoenix.{PubSub}
  require Logger

  def cosmic(conn, _params) do
    spawn(fn -> Cosmic.fetch_all() end)

    json(conn, %{
      "unnecessary" => "Ben implemented webhooks! No need to visit hit this link any more, but an update just happened just in case. If it's not updating, contact Ben. Thanks!"
    })
  end
end
