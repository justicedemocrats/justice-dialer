defmodule JusticeDialer.LoginRecord do
  @claim_tz "America/Los_Angeles"
  import ShortMaps

  def record_login_claimed(
        ~m(email phone name calling_from),
        username,
        client
      ) do
    day = Timex.now(@claim_tz) |> Timex.format!("{0D}-{0M}-{YYYY}")
    Mongo.insert_one(:mongo, "claims", ~m(email phone name calling_from username client day))
  end

  def who_claimed(username) do
    day = Timex.now(@claim_tz) |> Timex.format!("{0D}-{0M}-{YYYY}")

    query = %{"username" => %{"$regex" => username, "$options" => "i"}, "day" => day}

    case Mongo.find_one(:mongo, "claims", query) do
      nil ->
        yesterday_query =
          Map.put(
            query,
            "day",
            Timex.now(@claim_tz) |> Timex.shift(days: -1) |> Timex.format!("{0D}-{0M}-{YYYY}")
          )

        Mongo.find_one(:mongo, "claims", yesterday_query)

      map ->
        Map.drop(map, ~w(_id))
    end
  end

  def existing_login_for_email(email, client) do
    day = Timex.now(@claim_tz) |> Timex.format!("{0D}-{0M}-{YYYY}")

    case Mongo.find_one(:mongo, "claims", ~m(day client email)) do
      nil -> nil
      map -> Map.get(map, "username")
    end
  end
end
