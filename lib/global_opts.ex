defmodule GlobalOpts do
  defp get_brand(_conn, _params) do
    "jd"
  end

  defp is_mobile?(conn, _params) do
    case List.keyfind(conn.req_headers, "user-agent", 0, "") do
      {_head, tail} -> Browser.mobile?(tail)
      _ -> false
    end
  end

  def get(conn, params) do
    [brand: get_brand(conn, params), mobile: is_mobile?(conn, params), conn: conn]
  end
end
