defmodule JusticeDialer.Router do
  use JusticeDialer.Web, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(JusticeDialer.TurboVdomPlug, [])
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", JusticeDialer do
    pipe_through(:browser)

    get("/", PageController, :index)
    get("/candidate/:candidate", PageController, :candidate)

    get("/login-iframe/:client", LoginController, :get_iframe)
    post("/login-iframe/:client", LoginController, :post_iframe)

    get("/login", LoginController, :get)
    get("/logins/download", LoginController, :get_logins)
    post("/login", LoginController, :post)

    get("/info/:info", InfoController, :get)

    get("/call-aid/:candidate", PageController, :call_aid)
    post("/call-aid/:candidate", PageController, :easy_volunteer)
  end

  scope "/api", JusticeDialer do
    pipe_through(:api)

    get("/call/who-claimed/:client/:login", LoginController, :who_claimed)
    get("/update/cosmic", UpdateController, :cosmic)
    post("/update/cosmic", UpdateController, :cosmic)
  end

  defp handle_errors(conn, %{kind: kind, reason: reason, stack: stacktrace}) do
    Rollbax.report(kind, reason, stacktrace)
  end
end
