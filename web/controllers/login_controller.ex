defmodule JusticeDialer.LoginController do
  use JusticeDialer.Web, :controller
  import ShortMaps
  require Logger
  alias JusticeDialer.TwoFactor
  alias JusticeDialer.TwoFactorToken

  def get(conn, params) do
    groups =
      JusticeDialer.LoginConfig.get_all()
      |> Enum.filter(& &1["is_group"])

    render(conn, "login.html", [title: "Call", groups: groups] ++ GlobalOpts.get(conn, params))
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

  def reset_logins(conn, %{"secret" => input_secret}) do
    case Application.get_env(:justice_dialer, :update_secret) do
      ^input_secret ->
        JusticeDialer.Logins.reset()
        text(conn, "The logins have been reset")

      correct_secret ->
        Logger.info("User supplied #{input_secret} Should have supplied #{correct_secret}.")
        text(conn, "Wrong secret. Contact Ben.")
    end
  end

  def reset_logins(conn, _params) do
    text(
      conn,
      "Missing secret. Proper usage is https://justicedialer.com/logins/reset?secret=thingfromben"
    )
  end

  def get_report(conn, params = %{"secret" => @secret}) do
    render(
      conn,
      "login-report.html",
      [layout: {JusticeDialer.LayoutView, "empty.html"}] ++ GlobalOpts.get(conn, params)
    )
  end

  def who_claimed(conn, _params = ~m(client login)) do
    result =
      case Ak.DialerLogin.who_claimed(client, login) do
        ~m(email calling_from phone) -> ~m(email calling_from phone login)
        nil -> %{error: "Not found"}
      end

    json(conn, result)
  end

  def who_claimed_many(conn, _params = ~m(client logins)) do
    results =
      Enum.map(logins, fn login ->
        Task.async(fn ->
          case Ak.DialerLogin.who_claimed(client, login) do
            ~m(email calling_from phone) -> ~m(login email calling_from phone)
            nil -> nil
          end
        end)
      end)
      |> Enum.map(&Task.await(&1, 10_000))

    json(conn, results)
  end

  def who_claimed_infer(conn, ~m(login)) do
    client_match =
      JusticeDialer.LoginConfig.get_all()
      |> Enum.filter(
        &String.contains?(
          String.downcase(login),
          String.downcase(&1["prefix"])
        )
      )
      |> List.first()

    case client_match do
      ~m(client) -> who_claimed(conn, ~m(client login))
      nil -> json(conn, %{error: "Could not infer client"})
    end
  end

  def is_banned(~m(email phone)) do
    %{"metadata" => ~m(email_ban_list phone_ban_list)} = Cosmic.get("dialer-banlist")

    email_tests =
      email_ban_list
      |> String.split("\n")
      |> Enum.map(fn pattern ->
        {:ok, regex} = Regex.compile(pattern)
        regex
      end)
      |> Enum.filter(fn regex -> Regex.match?(regex, email) end)

    phone_tests =
      phone_ban_list
      |> String.split("\n")
      |> Enum.map(fn pattern ->
        {:ok, regex} = Regex.compile(pattern)
        regex
      end)
      |> Enum.filter(fn regex -> Regex.match?(regex, phone) end)

    length(email_tests) > 0 or length(phone_tests) > 0
  end

  def send_login_webhook(data) do
    %{"metadata" => ~m(login_claimed)} = Cosmic.get("dialer-webhooks")

    if login_claimed != "" and login_claimed != nil do
      HTTPotion.post(login_claimed, body: Poison.encode!(data))
    end
  end

  def post(conn, params = ~m(email phone name)) do
    client = "jd"
    TwoFactor.send_code(phone, Map.get(params, "verification_method", "text"))

    render(
      conn,
      "two-factor.html",
      [phone: phone, email: email, phone: phone, name: name, calling_from: params["calling_from"]] ++
        GlobalOpts.get(conn, params)
    )
  end

  def get_iframe(conn, params = %{"client" => client}) do
    conn
    |> delete_resp_header("x-frame-options")
    |> render(
      "login-iframe.html",
      client: client,
      layout: {JusticeDialer.LayoutView, "empty.html"},
      use_two_factor: use_two_factor?(client),
      use_post_sign: Map.has_key?(params, "post_sign"),
      post_sign_url: Map.get(params, "post_sign")
    )
  end

  def post_iframe(conn, params = ~m(email phone name client)) do
    use_two_factor = use_two_factor?(client)
    use_post_sign = Map.has_key?(params, "post_sign")
    post_sign_url = Map.get(params, "post_sign")

    if use_two_factor do
      TwoFactor.send_code(phone, Map.get(params, "verification_method", "text"))

      conn
      |> delete_resp_header("x-frame-options")
      |> render(
        "two-factor-iframe.html",
        phone: phone,
        email: email,
        name: name,
        calling_from: params["calling_from"],
        client: client,
        layout: {JusticeDialer.LayoutView, "empty.html"},
        use_post_sign: use_post_sign,
        post_sign_url: post_sign_url
      )
    else
      ~m(username password) = claim_login(params, client)
      layout = {JusticeDialer.LayoutView, "empty.html"}

      conn
      |> delete_resp_header("x-frame-options")
      |> render(
        "login-iframe-claimed.html",
        Enum.into(~m(username password layout post_sign_url use_post_sign client)a, [])
      )
    end
  end

  def post_two_factor(conn, params = ~m(code phone email name calling_from)) do
    if TwoFactor.is_correct_code?(phone, code) do
      ~m(username password) = claim_login(params, "jd")
      title = "Call"
      %{"content" => call_page} = Cosmic.get("call-page")

      render(
        conn,
        "login-submitted.html",
        Enum.into(~m(username password title call_page)a, []) ++ GlobalOpts.get(conn, params)
      )
    else
      render(
        conn,
        "two-factor.html",
        [
          phone: phone,
          email: email,
          name: name,
          calling_from: calling_from,
          error: "Incorrect code."
        ] ++ GlobalOpts.get(conn, params)
      )
    end
  end

  def post_two_factor_iframe(conn, params = ~m(code client phone name email calling_from)) do
    use_post_sign = Map.has_key?(params, "post_sign")
    post_sign_url = Map.get(params, "post_sign")

    if TwoFactor.is_correct_code?(phone, code) do
      ~m(username password) = claim_login(params, client)
      layout = {JusticeDialer.LayoutView, "empty.html"}

      conn
      |> delete_resp_header("x-frame-options")
      |> render(
        "login-iframe-claimed.html",
        Enum.into(~m(username password layout post_sign_url use_post_sign client)a, [])
      )
    else
      conn
      |> delete_resp_header("x-frame-options")
      |> render(
        "two-factor-iframe.html",
        phone: phone,
        name: name,
        email: email,
        calling_from: calling_from,
        error: "Incorrect code.",
        client: client,
        use_post_sign: use_post_sign,
        post_sign_url: post_sign_url,
        layout: {JusticeDialer.LayoutView, "empty.html"}
      )
    end
  end

  def claim_login(params = ~m(email phone name), client) do
    current_username = Ak.DialerLogin.existing_login_for_email(email, client)
    action_calling_from = params["calling_from"] || "unknown"

    ~m(username password) =
      cond do
        is_banned(~m(email phone)) ->
          JusticeDialer.Logins.phony(client)

        current_username == nil ->
          JusticeDialer.Logins.next_login(client)

        true ->
          %{
            "username" => current_username,
            "password" => JusticeDialer.Logins.password_for(current_username)
          }
      end

    spawn(fn ->
      Ak.DialerLogin.record_login_claimed(
        ~m(email phone name action_calling_from),
        username,
        client,
        true
      )

      send_login_webhook(~m(email phone name action_calling_from username client))
    end)

    ~m(username password)
  end

  def callback(conn, params = ~m(To)) do
    code =
      TwoFactor.code_for(params["To"])
      |> String.split("")
      |> Enum.filter(&(&1 != " "))
      |> Enum.join(", ")
      |> String.trim()

    message =
      "Your dialer verification code is #{code}. Once again, that is #{code}. Thank you for making calls."

    twiml = JusticeDialer.Twiml.say_message(message)

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, twiml)
  end

  def use_two_factor?(client) do
    JusticeDialer.LoginConfig.get_all()
    |> Enum.filter(&(&1["client"] == client))
    |> List.first()
    |> Map.get("use_two_factor")
  end

  def api_login(conn, params = ~m(email phone name client)) do
    use_two_factor = use_two_factor?(client)

    if use_two_factor do
      case TwoFactorToken.step_one(params) do
        {:ok, identifier} ->
          json(conn, ~m(identifier))

        {:error, error} ->
          conn
          |> put_status(400)
          |> json(~m(error))
      end
    else
      ~m(username password) = claim_login(params, client)
      json(conn, ~m(username password))
    end
  end

  def api_two_factor(conn, params = ~m(code identifier client)) do
    case TwoFactorToken.step_two(~m(code identifier)) do
      {:ok, payload} ->
        IO.inspect(payload)
        ~m(username password) = claim_login(payload, client)
        json(conn, ~m(username password))

      {:error, error} ->
        conn
        |> put_status(400)
        |> json(~m(error))
    end
  end
end
