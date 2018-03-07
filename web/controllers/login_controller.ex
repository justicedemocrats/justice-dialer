defmodule JusticeDialer.LoginController do
  use JusticeDialer.Web, :controller
  import ShortMaps
  require Logger

  def get(conn, params) do
    render(conn, "login.html", [title: "Call"] ++ GlobalOpts.get(conn, params))
  end

  def post(conn, params = ~m(email phone name)) do
    global_opts = GlobalOpts.get(conn, params)
    client = Keyword.get(global_opts, :brand)

    # current_username = nil
    current_username = Ak.DialerLogin.existing_login_for_email(email, client)

    action_calling_from = params["calling_from"] || "unknown"

    %{"metadata" => ~m(banlist)} = Cosmic.get("dialer-banlist")
    banlist = String.split(banlist, "\n")

    ~m(username password) =
      cond do
        Enum.member?(banlist, email) ->
          JusticeDialer.Logins.phony(client)

        current_username == nil ->
          JusticeDialer.Logins.next_login(client)

        true ->
          %{
            "username" => current_username,
            "password" => JusticeDialer.Logins.password_for(current_username)
          }
      end

    Ak.DialerLogin.record_login_claimed(
      ~m(email phone name action_calling_from),
      username,
      client,
      true
    )

    %{"content" => call_page, "metadata" => metadata} = Cosmic.get("call-page")

    content_key = "#{Keyword.get(global_opts, :brand)}_content"

    chosen_content =
      if metadata[content_key] && metadata[content_key] != "" do
        metadata[content_key]
      else
        call_page
      end

    render(
      conn,
      "login-submitted.html",
      [
        username: String.trim(username),
        password: String.trim(password),
        title: "Call",
        call_page: chosen_content
      ] ++ global_opts
    )
  end

  def get_logins(conn, %{"secret" => input_secret}) do
    case Application.get_env(:justice_dialer, :update_secret) do
      ^input_secret ->
        csv_content =
          JusticeDialer.Logins.fetch()
          |> Enum.map(fn line ->
            Enum.join(line, ",")
          end)
          |> Enum.join("\n")

        conn
        |> put_resp_content_type("text/csv")
        |> put_resp_header(
          "content-disposition",
          "attachment; filename=\"logins-#{Timex.now() |> DateTime.to_iso8601()}.csv\""
        )
        |> send_resp(200, csv_content)

      correct_secret ->
        Logger.info("User supplied #{input_secret} Should have supplied #{correct_secret}.")
        text(conn, "Wrong secret. Contact Ben.")
    end
  end

  def get_logins(conn, _params) do
    text(
      conn,
      "Missing secret. Proper usage is https://justicedialer.com/logins/download?secret=thingfromben"
    )
  end

  def get_report(conn, params = %{"secret" => @secret}) do
    render(
      conn,
      "login-report.html",
      [layout: {JusticeDialer.LayoutView, "empty.html"}] ++ GlobalOpts.get(conn, params)
    )
  end

  def get_iframe(conn, params = %{"client" => client}) do
    conn
    |> delete_resp_header("x-frame-options")
    |> render(
      "login-iframe.html",
      client: client,
      layout: {JusticeDialer.LayoutView, "empty.html"},
      use_post_sign: Map.has_key?(params, "post_sign"),
      post_sign_url: Map.get(params, "post_sign")
    )
  end

  def post_iframe(conn, params = ~m(email phone name client)) do
    # current_username = nil
    current_username = Ak.DialerLogin.existing_login_for_email(email, client)
    action_calling_from = params["calling_from"] || "unknown"

    %{"metadata" => ~m(banlist)} = Cosmic.get("dialer-banlist")
    banlist = String.split(banlist, "\n")

    ~m(username password) =
      cond do
        Enum.member?(banlist, email) ->
          JusticeDialer.Logins.phony(client)

        current_username == nil ->
          JusticeDialer.Logins.next_login(client)

        true ->
          %{
            "username" => current_username,
            "password" => JusticeDialer.Logins.password_for(current_username)
          }
      end

    IO.inspect(
      Ak.DialerLogin.record_login_claimed(
        ~m(email phone name action_calling_from),
        username,
        client,
        false
      )
    )

    conn
    |> delete_resp_header("x-frame-options")
    |> render(
      "login-iframe-claimed.html",
      username: String.trim(username),
      password: String.trim(password),
      client: client,
      use_post_sign: Map.has_key?(params, "post_sign"),
      post_sign_url: Map.get(params, "post_sign"),
      layout: {JusticeDialer.LayoutView, "empty.html"}
    )
  end

  def who_claimed(conn, _params = ~m(client login)) do
    result =
      case Ak.DialerLogin.who_claimed(client, login) do
        ~m(email calling_from phone) -> ~m(email calling_from phone)
        nil -> %{error: "Not found"}
      end

    json(conn, result)
  end
end
