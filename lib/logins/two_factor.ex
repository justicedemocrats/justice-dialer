defmodule JusticeDialer.TwoFactor do
  use Agent
  @code_length 5

  def start_link do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def send_code(phone, "call") do
    code = code_for(phone)

    call =
      ExTwilio.Call.create(%{
        from: Application.get_env(:justice_dialer, :two_factor_from_number),
        to: phone,
        body: "Your dialer verification code is: #{code}",
        url: Application.get_env(:justice_dialer, :two_factor_callback_url)
      })

    case call do
      {:ok, call} ->
        record_normalized_code_pair(call.to, code)
        {:ok, code}

      {:error, _error, 400} ->
        {:error, "Invalid_phone"}

      {:error, _error, _erro_code} ->
        {:error, "System error"}
    end
  end

  def send_code(phone, "text") do
    code = code_for(phone)

    msg =
      ExTwilio.Message.create(%{
        from: Application.get_env(:justice_dialer, :two_factor_from_number),
        to: phone,
        body: "Your dialer verification code is: #{code}"
      })

    case msg do
      {:ok, resp} -> {:ok, code}
      {:error, _error, 400} -> {:error, "Invalid phone"}
      {:error, _error, _erro_code} -> {:error, "System_error"}
    end
  end

  def is_correct_code?(phone, code) do
    code_for(phone) == code
  end

  # TODO - add expiration
  def code_for(phone) do
    Agent.get_and_update(__MODULE__, fn state ->
      if Map.has_key?(state, phone) do
        {state[phone], state}
      else
        code = gen_code()
        {code, Map.put(state, phone, code)}
      end
    end)
  end

  def record_normalized_code_pair(phone, code) do
    Agent.update(__MODULE__, fn state ->
      Map.put(state, phone, code)
    end)
  end

  def gen_code do
    1..@code_length
    |> Enum.map(fn _ -> Enum.random(0..9) end)
    |> Enum.join("")
  end
end
