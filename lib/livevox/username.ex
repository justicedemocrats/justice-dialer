defmodule Livevox.Username do
  import ShortMaps

  def update_or_create(params = ~m(loginId firstName lastName password phone wrapUpTime services)) do
    %{body: ~m(agent)} = Livevox.Username.find(~m(loginId))

    match =
      Enum.filter(agent, &(String.upcase(&1["loginId"]) == String.upcase(loginId)))
      |> List.first()

    case match do
      nil -> create(params)
      ~m(id) -> update(id, params)
    end
  end

  def create(~m(loginId firstName lastName password phone wrapUpTime services)) do
    body =
      Map.merge(~m(loginId firstName lastName password phone wrapUpTime), %{
        "active" => true,
        "homeAgent" => true,
        "assignedService" => Enum.map(services, fn id -> ~m(id) end)
      })

    Livevox.Api.post("configuration/v6.0/agents", body: body)
  end

  def update(id, ~m(firstName lastName password phone wrapUpTime services)) do
    body =
      Map.merge(~m(firstName lastName password phone wrapUpTime), %{
        "active" => true,
        "homeAgent" => true,
        "unlock" => true
      })

    Livevox.Api.put("configuration/v6.0/agents/#{id}", body: body)

    %{body: ~m(assignedService)} = Livevox.Api.get("configuration/v6.0/agents/#{id}")
    existing_service_ids = Enum.map(assignedService, &"#{&1["id"]}") |> MapSet.new()
    services_set = MapSet.new(services)

    to_remove = MapSet.difference(existing_service_ids, services_set)
    to_add = MapSet.difference(services_set, existing_service_ids)

    Enum.map(to_remove, &Livevox.Api.delete("configuration/v6.0/agents/#{id}/services/#{&1}"))
    Enum.map(to_add, &Livevox.Api.put("configuration/v6.0/agents/#{id}/services/#{&1}"))

    :ok
  end

  def destroy(id) do
    Livevox.Api.delete("configuration/v6.0/agents/#{id}")
  end

  def find(search) do
    Livevox.Api.post(
      "configuration/v6.0/agents/search",
      body: search,
      query: %{offset: 0, count: 1000}
    )
  end
end
