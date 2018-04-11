defmodule Livevox.Api do
  @moduledoc """
  Extension of HTTPoition

  Provides raw GET, POST, PUT, DELETE for the livevox API
  """
  use HTTPotion.Base

  @base "https://api.na4.livevox.com"

  # --------------- Process request ---------------
  defp process_url(url) do
    "#{@base}/#{url}"
  end

  defp process_request_headers(hdrs) do
    access_token = Application.get_env(:livevox, :access_token)

    hdrs =
      Enum.into(
        hdrs,
        Accept: "application/json",
        "Content-Type": "application/json",
        Authorization: "Bearer #{access_token}"
      )

    if Keyword.has_key?(hdrs, :no_session) do
      Keyword.delete(hdrs, :no_session)
    else
      Keyword.put(hdrs, :"LV-Session", Livevox.Session.session_id())
    end
  end

  defp process_request_body(body) when is_map(body), do: Poison.encode!(body)
  defp process_request_body(body), do: body

  # --------------- Process response ---------------
  defp process_response_body(raw) do
    case Poison.decode(raw) do
      {:ok, decoded} ->
        decoded

      # {:error, {_, _, _}} -> raw
      {:error, _, _} ->
        raw
    end
  end
end
