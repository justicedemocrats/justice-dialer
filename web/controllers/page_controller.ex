defmodule JusticeDialer.PageController do
  import ShortMaps
  use JusticeDialer.Web, :controller
  require Logger

  def index(conn, params) do
    render_call(conn, params)
  end

  def candidate(conn, params = %{"candidate" => candidate}) do
    candidate = Cosmic.get(candidate)
    render_call(conn, params, candidate)
  end

  defp render_call(conn, params, candidate \\ nil) do
    global_opts = GlobalOpts.get(conn, params)
    brand = Keyword.get(global_opts, :brand)

    candidate =
      cond do
        match?(%{"status" => "error"}, candidate) -> nil
        is_map(candidate) -> candidate
        is_nil(candidate) -> nil
        true -> Cosmic.get(candidate)
      end

    candidate_calling_page =
      cond do
        candidate != nil -> candidate["metadata"]["calling_prompt"]
        true -> ""
      end

    ~m(priority rest off_hours)a = callable_candidates(brand)

    callable_slugs =
      Enum.concat(priority, rest)
      |> Enum.map(& &1.slug)

    draft = Map.has_key?(params, "draft")

    render(
      conn,
      "call.html",
      [
        title: "Call Voters",
        candidate: candidate,
        candidate_is_open: on_hours?(candidate),
        calling_script_link: candidate["metadata"]["calling_script_link"],
        candidate_calling_page: candidate_calling_page,
        priority: priority,
        rest: rest,
        off_hours: off_hours,
        callable_slugs: callable_slugs,
        close_time: close_time(candidate),
        draft: draft,
        calling_page_is_down: Cosmic.get("calling-page-is-down")
      ] ++ global_opts
    )
  end

  def call_aid(conn, params = %{"candidate" => candidate}) do
    %{"title" => title} = Cosmic.get(candidate)

    events = EventHelp.events_for(title)

    render(
      conn,
      "call-aid.html",
      [events: events, no_header: true, no_footer: true, slug: candidate] ++
        GlobalOpts.get(conn, params)
    )
  end

  def easy_volunteer(
        conn,
        params = %{
          "candidate" => candidate,
          "phone" => phone,
          "email" => email,
          "first_name" => first_name,
          "last_name" => last_name
        }
      ) do
    %{"title" => title} = Cosmic.get(candidate)

    events = EventHelp.events_for(title)

    %{id: id} =
      Osdi.PersonSignup.main(%{
        person: %{
          phone_numbers: [%{number: phone, primary: true}],
          email_addresses: [%{primary: true, address: email}],
          given_name: first_name,
          family_name: last_name
        },
        add_tags: ["Action: Joined as Volunteer: #{title}"]
      })

    render(
      conn,
      "call-aid.html",
      [events: events, no_header: true, no_footer: true, slug: candidate, person: id] ++
        GlobalOpts.get(conn, params)
    )
  end

  def legacy_redirect(conn, _params = %{"candidate" => candidate, "selected" => _selected}) do
    %{"metadata" => %{"district" => district}} = Cosmic.get(candidate)

    conn
    |> put_resp_cookie("district", district, http_only: false)
    |> redirect(to: "/act/call")
  end

  def legacy_redirect(conn, _params = %{"candidate" => candidate}) do
    %{"metadata" => %{"district" => district}} = Cosmic.get(candidate)

    conn
    |> put_resp_cookie("district", district, http_only: false)
    |> redirect(to: "/act")
  end

  defp event_action_options(_conn, _params) do
    [
      %{icon: "event.html", label: "Attend an Event", href: "/events"},
      %{icon: "host.html", label: "Host an Event", href: "/form/submit-event"}
    ]
  end

  defp home_action_options(_conn, _params) do
    [
      %{icon: "call-icon.html", label: "Call Voters", href: "/act/call"},
      %{
        icon: "nominate-icon.html",
        label: "Nominate a Candidate",
        href: "https://justicedemocrats.com/nominate"
      },
      %{
        icon: "district-icon.html",
        label: "Tell Us About Your District",
        href:
          "https://docs.google.com/forms/d/e/1FAIpQLSe8CfK0gUULEVpYFm9Eb4iyGOL-_iDl395qB0z4hny7ek4iNw/viewform?refcode=www.google.com"
      },
      %{icon: "team-icon.html", label: "Join a National Team", href: "/form/teams"}
    ]
  end

  defp candidate_options(district) do
    candidate = if district, do: District.get_candidate(district), else: nil

    closest_candidate =
      if district != nil and candidate == nil do
        District.closest_candidate(district)
      else
        nil
      end

    %{candidate: candidate, closest_candidate: closest_candidate}
  end

  defp extract_district(conn, params) do
    district = params["district"] || conn.cookies["district"]
    district = if district == "clear", do: nil, else: district
    district
  end

  defp callable_candidates(brand \\ "jd") do
    broken_down =
      "candidates"
      |> Cosmic.get_type()
      |> Enum.filter(fn %{"metadata" => %{"brands" => bs}} -> Enum.member?(bs, brand) end)
      |> Enum.filter(&is_callable/1)
      |> Enum.sort_by(fn %{"metadata" => ~m(district)} -> district end)
      |> Enum.group_by(
        fn cand = %{"metadata" => ~m(priority)} ->
          cond do
            on_hours?(cand) != true -> :off_hours
            priority == "True" -> :priority
            true -> :rest
          end
        end,
        fn ~m(slug title metadata) -> ~m(slug title metadata)a end
      )

    broken_down
    |> ensure_exists(:priority)
    |> ensure_exists(:off_hours)
    |> ensure_exists(:rest)
  end

  defp ensure_exists(map, key) do
    if Map.has_key?(map, key) do
      map
    else
      Map.put(map, key, [])
    end
  end

  # 'vulgar' here means literally away from the church, or not a holy day
  def on_hours?(%{
        "metadata" =>
          metadata = %{"callable" => "Callable", "time_zone" => time_zone, "district" => district}
      }) do
    ~m(abbreviation)a = Timex.Timezone.get(time_zone)
    now = time_zone |> Timex.now()
    local_hours = now.hour
    day_of_week = Timex.weekday(now)

    case JusticeDialer.CampaignConfig.is_open?(district) do
      nil ->
        [vulgar_open, vulgar_close] =
          case metadata["open_time_monday_saturday"] do
            time_range when is_binary(time_range) ->
              time_range
              |> String.split("-")
              |> Enum.map(&(Integer.parse(&1) |> Tuple.to_list() |> List.first()))

            _ ->
              [10, 21]
          end

        [holy_open, holy_close] =
          case metadata["open_time_sunday"] do
            time_range when is_binary(time_range) ->
              time_range
              |> String.split("-")
              |> Enum.map(&(Integer.parse(&1) |> Tuple.to_list() |> List.first()))

            _ ->
              [12, 21]
          end

        times_for = fn
          7 -> [holy_open, holy_close]
          _ -> [vulgar_open, vulgar_close]
        end

        [today_open, today_close] = times_for.(day_of_week)
        [tomorrow_open, tomorrow_close] = times_for.(day_of_week + 1)

        cond do
          local_hours >= today_open and local_hours < today_close ->
            true

          local_hours < today_open ->
            {:before,
             "#{today_open} #{if today_open == 12, do: "PM", else: "AM"} #{abbreviation} "}

          local_hours >= today_close ->
            {:after, "#{tomorrow_open} AM #{abbreviation} "}
        end

      boolean ->
        boolean
    end
  end

  def on_hours?(nil) do
    false
  end

  def close_time(nil) do
    9
  end

  def close_time(%{"metadata" => metadata}) do
    day_of_week = Timex.weekday(Timex.now())

    window_key =
      case day_of_week do
        7 -> "open_time_sunday"
        _ -> "open_time_monday_saturday"
      end

    Map.get(metadata, window_key, "10-21")
    |> String.split("-")
    |> List.last()
    |> (&(Integer.parse(&1) |> Tuple.to_list() |> List.first())).()
    |> (&(&1 - 12)).()
  end

  defp is_callable(%{"metadata" => %{"callable" => "Callable"}}) do
    true
  end

  defp is_callable(_else) do
    false
  end
end
