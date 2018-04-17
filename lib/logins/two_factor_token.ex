defmodule JusticeDialer.TwoFactorToken do
  use Agent
  import ShortMaps
  alias JusticeDialer.TwoFactor

  @code_length 5

  def start_link do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def step_one(payload = ~m(phone verification_method)) do
    with {:ok, code} <- TwoFactor.send_code(phone, verification_method) do
      identifier = gen_identifier()

      Agent.update(__MODULE__, fn state ->
        put_in(state, [identifier], ~m(code payload))
      end)

      {:ok, identifier}
    else
      error_clause -> error_clause
    end
  end

  def step_two(~m(identifier code)) do
    Agent.get_and_update(__MODULE__, fn state ->
      cond do
        Map.has_key?(state, identifier) and state[identifier]["code"] == code ->
          resp = {:ok, state[identifier]["payload"]}
          new_state = Map.drop(state, [identifier])
          {resp, new_state}

        Map.has_key?(state, identifier) ->
          resp = {:error, "Wrong code"}
          {resp, state}

        true ->
          resp = {:error, "Unknown identifier"}
          {resp, state}
      end
    end)
  end

  def gen_identifier do
    :crypto.strong_rand_bytes(14) |> Base.url_encode64() |> binary_part(0, 14)
  end
end
