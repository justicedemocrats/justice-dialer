defmodule JusticeDialer.LoginConfig do
  use AirtableConfig
  import ShortMaps

  def key, do: Application.get_env(:justice_dialer, :airtable_key)
  def base, do: Application.get_env(:justice_dialer, :airtable_base)
  def table, do: "Login%20Pools"
  def view, do: "Grid view"
  def into_what, do: []

  def filter_record(~m(fields)) do
    Map.has_key?(fields, "Active") and fields["Active"] == true
  end

  def process_record(~m(fields)) do
    display_name = fields["Reference Name"]
    prefix = fields["Login Prefix"]
    service_group = fields["Service Group"]
    count = fields["Count"]
    client = fields["Iframe Slug"]
    is_group = fields["Is Group"] == true
    is_campaign = fields["Is Campaign"] == true
    wrap_up = fields["Wrap Up Time"]
    use_two_factor = fields["Two-Factor Enabled"]

    custom_services =
      case fields["Custom Services"] do
        nil -> nil
        str -> String.split(str, ",") |> Enum.map(&String.trim(&1))
      end

    ~m(prefix custom_services service_group count
       client is_group wrap_up display_name use_two_factor
       is_campaign)
  end
end
