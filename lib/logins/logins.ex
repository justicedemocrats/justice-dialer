defmodule JusticeDialer.Logins do
  import ShortMaps
  require Logger

  @words "./lib/words.csv"
         |> File.stream!()
         |> CSV.decode()
         |> Enum.map(fn {:ok, word} -> word end)

  def reset do
    logins =
      Enum.concat([
        gen_logins(1000, "BncVol", 60, "bnc"),
        gen_logins(3000, "JdVol", 60, "jd"),
        gen_logins(1000, "BetoVol", 90, "beto"),
        gen_logins(100, "BetoStaff", 300, "beto-staff")
      ])

    Db.delete_logins()
    Logger.info("[dialer-update] deleted yesterday's logins")
    Db.insert_logins(logins)
    Logger.info("[dialer-update] inserted new logins")

    Enum.each(~w(bnc jd beto beto-staff), fn client ->
      Db.reset_claimed(client)
      Logger.info("[dialer-update] reset claimed for #{client}")
    end)
  end

  def next_login(client) do
    client_count = Db.inc_claimed(client)
    Db.find_login(%{"client" => client, "index" => client_count})
  end

  def gen_logins(count, first_name, wrap_up_time, client) do
    1..count
    |> Enum.map(fn n ->
         %{
           username: "#{first_name}#{n}",
           password: random_password(),
           first_name: first_name,
           last_name: "Vol#{n}",
           wrap_up_time: wrap_up_time,
           index: n,
           client: client
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
    Enum.flat_map(~w(beto beto-staff bnc jd), fn client ->
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
               "Callers",
               "",
               ""
             ],
             services_for(client)
           )
         end)
    end)
  end

  def services_for("beto") do
    [1_011_627]
  end

  def services_for("beto-staff") do
    [1_012_486, 1_011_627]
  end

  def services_for(client) do
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
end
