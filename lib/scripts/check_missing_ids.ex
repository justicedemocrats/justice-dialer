defmodule Scripts.CheckMissingIds do
  import ShortMaps

  def go do
    Cosmic.get_type("candidates")
    |> Enum.filter(fn %{"metadata" => ~m(callable)} -> callable == "Callable" end)
    |> Enum.map(&{&1["title"], get_in(&1, ~w(metadata livevox_service_id))})
  end
end
