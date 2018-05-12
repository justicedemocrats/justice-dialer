defmodule JusticeDialer.Logins do
  import ShortMaps
  require Logger

  @words "./lib/words.csv"
         |> File.stream!()
         |> CSV.decode()
         |> Enum.map(fn {:ok, word} -> word end)

  @login_load_batch_size 5

  def reset do
    pools = JusticeDialer.LoginConfig.get_all()
    clients = Enum.map(pools, & &1["client"])

    logins =
      pools
      |> Enum.map(fn ~m(count wrap_up client prefix) ->
        gen_logins(count, prefix, wrap_up, client)
      end)
      |> Enum.concat()

    Db.delete_logins()
    Logger.info("[dialer-update] deleted yesterday's logins")
    Db.insert_logins(logins)
    Logger.info("[dialer-update] inserted new logins")

    Enum.each(clients, fn client ->
      Db.reset_claimed(client)
      Logger.info("[dialer-update] reset claimed for #{client}")
    end)

    Logger.info("Reloading all logins")
    update_livevox()
    Logger.info("Updated logins in livevox")
  end

  def next_login(client) do
    client_count = Db.inc_claimed(client)
    # wrap around 1000 just in case
    to_fetch = rem(client_count, 1000)
    Db.find_login(%{"client" => client, "index" => to_fetch})
  end

  def phony("jd") do
    %{
      "username" => "JdDialerVol#{Kernel.trunc(:rand.uniform() * 999)}",
      "password" => random_password()
    }
  end

  def phony("beto") do
    %{
      "username" => "BetoVol#{Kernel.trunc(:rand.uniform() * 999)}",
      "password" => random_password()
    }
  end

  def phony("bnc") do
    %{
      "username" => "BncVol#{Kernel.trunc(:rand.uniform() * 999)}",
      "password" => random_password()
    }
  end

  def gen_logins(count, first_name, wrap_up_time, client) do
    1..count
    |> Enum.map(fn n ->
      %{
        "username" => "#{first_name}#{n}",
        "password" => random_password(),
        "first_name" => first_name,
        "last_name" => "Vol#{n}",
        "wrap_up_time" => wrap_up_time,
        "index" => n,
        "client" => client
      }
    end)
  end

  defp random_password do
    "#{@words |> Enum.take_random(1) |> Enum.join("_")}#{
      1..6 |> Enum.map(fn _n -> Enum.random(1..9) end) |> Enum.join("")
    }"
  end

  def password_for(username) do
    ~m(password) = Db.find_login(%{"username" => username})
    password
  end

  def fetch do
    pools = JusticeDialer.LoginConfig.get_all()

    Enum.flat_map(pools, fn pool = ~m(client) ->
      Db.logins_for_client(client)
      |> Enum.map(fn l ->
        ~m(username first_name last_name password wrap_up_time) = l

        Enum.concat(
          [
            username,
            password,
            first_name,
            last_name,
            1234,
            wrap_up_time,
            1,
            0,
            agent_team_for(pool),
            "",
            ""
          ],
          services_for(pool)
        )
      end)
    end)
  end

  def update_livevox do
    JusticeDialer.LoginConfig.get_all()
    |> Stream.each(&load_pool_into_livevox/1)
    |> Stream.run()
  end

  def update_services do
    JusticeDialer.LoginConfig.get_all()
    |> Stream.each(&load_pool_into_livevox(&1, true))
    |> Stream.run()
  end

  def load_pool_into_livevox(pool = ~m(client), only_update_services \\ false) do
    Logger.info("Loading #{client}")

    services = services_for(pool)

    Db.logins_for_client(client)
    |> Stream.with_index()
    |> Stream.map(&report/1)
    |> Stream.chunk_every(@login_load_batch_size)
    |> Stream.each(fn chunk ->
      Enum.map(
        chunk,
        &Task.async(fn -> load_login_into_livevox(&1, services, only_update_services) end)
      )
      |> Enum.each(&Task.await/1)
    end)
    |> Stream.run()

    HTTPotion.post(
      Application.get_env(:justice_dialer, :on_usernames_load),
      body: Poison.encode!(~m(client only_update_services))
    )

    Logger.info("Loaded #{client}")
  end

  def report({l, idx}) do
    if rem(idx, 10) == 0 do
      Logger.info("Did #{idx}")
    end

    l
  end

  def load_login_into_livevox(login, services, only_update_services) do
    ~m(username first_name last_name password wrap_up_time) = login
    loginId = username
    firstName = first_name
    lastName = last_name
    wrapUpTime = wrap_up_time
    phone = "1234"

    body = ~m(loginId firstName lastName password phone wrapUpTime services)

    if only_update_services do
      Livevox.Username.update_services(body)
    else
      Livevox.Username.update_or_create(body)
    end
  end

  def services_for(%{"service_group" => client}) when not is_nil(client) do
    if Timex.now("America/Los_Angeles").hour < 12 do
      services_for(client, fn _ -> true end)
    else
      services_for(client, fn cand ->
        case JusticeDialer.PageController.on_hours?(cand) do
          {:after, _} -> false
          _ -> true
        end
      end)
    end
  end

  def services_for(client, extra_filter) do
    Cosmic.get_type("candidates")
    |> Enum.filter(fn %{"metadata" => ~m(callable)} -> callable == "Callable" end)
    |> Enum.filter(fn %{"metadata" => ~m(brands)} -> Enum.member?(brands, client) end)
    |> Enum.filter(&extra_filter.(&1))
    |> Enum.flat_map(
      &case get_in(&1, ["metadata", "livevox_service_id"]) do
        string when is_binary(string) ->
          String.split(string, ",") |> Enum.map(fn s -> String.trim(s) end)

        int ->
          ["#{int}"]
      end
    )
  end

  def services_for(%{"custom_services" => services}) when is_list(services) do
    services
  end

  def agent_team_for(%{"is_campaign" => true}), do: "Campaign"
  def agent_team_for(%{"is_group" => true}), do: "Chapter"
  def agent_team_for(_), do: "Callers"
end
