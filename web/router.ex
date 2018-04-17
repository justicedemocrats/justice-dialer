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

  pipeline :iframe do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", JusticeDialer do
    pipe_through(:browser)

    get("/", PageController, :index)
    get("/candidate/:candidate", PageController, :candidate)

    get("/login", LoginController, :get)
    get("/logins/download", LoginController, :get_logins)
    get("/logins/reset", LoginController, :reset_logins)
    post("/login", LoginController, :post)
    post("/two-factor", LoginController, :post_two_factor)

    get("/info/:info", InfoController, :get)

    get("/call-aid/:candidate", PageController, :call_aid)
    post("/call-aid/:candidate", PageController, :easy_volunteer)
  end

  scope "/", JusticeDialer do
    pipe_through(:iframe)

    get("/login-iframe/:client", LoginController, :get_iframe)
    post("/login-iframe/:client", LoginController, :post_iframe)
    post("/two-factor-iframe/:client", LoginController, :post_two_factor_iframe)
  end

  scope "/api", JusticeDialer do
    pipe_through(:api)

    get("/call/who-claimed/infer-client/:login", LoginController, :who_claimed_infer)
    get("/call/who-claimed/:client/:login", LoginController, :who_claimed)
    post("/call/who-claimed-many/:client", LoginController, :who_claimed_many)

    get("/update/cosmic", UpdateController, :cosmic)
    post("/update/cosmic", UpdateController, :cosmic)

    post("/claim-login/:client", LoginController, :api_login)
    post("/verify-number/:client", LoginController, :api_two_factor)

    post("/callback", LoginController, :callback)
  end

  defp handle_errors(conn, %{kind: kind, reason: reason, stack: stacktrace}) do
    Rollbax.report(kind, reason, stacktrace)
  end
end
