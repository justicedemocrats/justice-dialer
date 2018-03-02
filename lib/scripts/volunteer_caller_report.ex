defmodule VolunteerCallerReport do
  def callers_for(service_fragment) do
    contents =
      Db.distinct("calls", "agent_name", %{
        "service_name" => %{"$regex" => ".*#{service_fragment}.*"},
        "timestamp" => %{"$gt" => Timex.now() |> Timex.shift(days: -7)}
      })
      |> Enum.filter(&(&1 != "" and &1 != nil))
      |> Enum.map(&Ak.DialerLogin.who_claimed("jd", &1))
      |> Enum.map(
        &Map.take(
          &1,
          ~w(email phone first_name last_name) |> Enum.map(fn f -> Map.take(&1, f) end)
        )
      )
      |> Enum.map(&Enum.join(&1, ","))
      |> Enum.join("\n")

    File.write("./#{service_fragment}.csv", contents)
  end
end
