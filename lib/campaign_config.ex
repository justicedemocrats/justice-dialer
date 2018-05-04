defmodule JusticeDialer.CampaignConfig do
  import ShortMaps
  use AirtableConfig

  def key, do: Application.get_env(:justice_dialer, :airtable_key)
  def base, do: Application.get_env(:justice_dialer, :airtable_base)
  def table, do: "Campaign%20Controls"
  def view, do: "Grid view"
  def into_what, do: []

  def filter_record(~m(fields)) do
    is_active_day(fields["Active Days of the Week"]) and Map.has_key?(fields, "Candidate")
  end

  def is_active_day(nil) do
    false
  end

  def is_active_day(day_string) when is_binary(day_string) do
    day_of_week = Timex.weekday(Timex.now("America/New_York"))
    active_days = day_string |> String.split(",")
    Enum.member?(active_days, "#{day_of_week}")
  end

  def process_record(~m(fields)) do
    district = fields["Service Regex"]
    candidate = fields["Candidate"]
    start_time = fields["Start Time (EST)"]
    end_time = fields["End Time (EST)"]
    ~m(district candidate start_time end_time)
  end

  def get_open_close(candidate_district) do
    get_all()
    |> Enum.find(fn ~m(district) ->
      String.downcase(candidate_district) == String.downcase(district)
    end)
    |> (fn
          nil ->
            nil

          ~m(start_time end_time) ->
            hour = Timex.now("America/New_York").hour
            {start_time, end_time}
        end).()
  end
end
