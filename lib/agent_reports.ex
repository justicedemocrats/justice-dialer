defmodule AgentReports do
  import ShortMaps

  def target_page, do: Application.get_env(:justice_dialer, :ak_agent_report_page)

  def go do
    emails = Db.calling_users()
    Enum.each(emails, &do_report/1)
  end

  def do_report(email) do
    produce_report(email)
    |> send_report()
  end

  def produce_report(email) do
    total_calls_made = call_count(email)
    call_breakdown = call_breakdown(email)

    Map.merge(call_breakdown, ~m(total_calls_made))
    |> Enum.map(fn {k, v} ->
      {"action_#{Macro.underscore(k)}", v}
    end)
    |> Enum.into(~m(email))
  end

  def send_report(action_body) do
    IO.inspect(Ak.Signup.process_signup(&(&1["id"] == target_page()), action_body))
  end

  def call_count(caller_email) do
    Db.count_calls(~m(caller_email))
  end

  def call_breakdown(caller_email) do
    Db.distinct(
      "calls",
      "full_on_screen_result",
      Map.merge(~m(caller_email), Db.within_24_hours())
    )
    |> Enum.map(fn full_on_screen_result ->
      Task.async(fn ->
        {full_on_screen_result, Db.count_calls(~m(caller_email full_on_screen_result))}
      end)
    end)
    |> Enum.map(&Task.await(&1, 100_000))
    |> Enum.into(%{})
  end
end
