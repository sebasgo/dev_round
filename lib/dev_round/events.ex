defmodule DevRound.Events do
  @moduledoc """
  The Events context.
  """

  import Ecto.Query, warn: false
  alias DevRound.Repo
  alias DevRound.Accounts.User
  alias DevRound.Events.Event
  alias DevRound.Events.EventSession
  alias DevRound.Events.Lang
  alias DevRound.Events.EventAttendee

  @doc """
  Returns the list of events.

  ## Examples

      iex> list_events()
      [%Event{}, ...]

  """
  def list_events() do
    Repo.all(Event)
  end

  def list_events(:current) do
    from(e in Event,
      where: e.end >= ^get_event_archival_datetime_utc() and e.published,
      order_by: [asc: e.begin]
    )
    |> Repo.all()
  end

  def list_events(:archived) do
    from(e in Event,
      where: e.end < ^get_event_archival_datetime_utc() and e.published,
      order_by: [desc: e.begin]
    )
    |> Repo.all()
  end

  def get_event_archival_datetime_utc do
    tz = Application.get_env(:dev_round, :time_zone)

    {:ok, now} = DateTime.now(tz)

    next_midnight_local =
      now
      |> DateTime.to_date()
      |> Date.shift(day: 1)
      |> DateTime.new!(~T[00:00:00], tz)

    DateTime.shift_zone!(next_midnight_local, "Etc/UTC")
  end

  @doc """
  Gets a single event.

  Raises `Ecto.NoResultsError` if the Event does not exist.

  ## Examples

      iex> get_event!(123)
      %Event{}

      iex> get_event!(456)
      ** (Ecto.NoResultsError)

  """
  def get_event!(slug_or_id, opts \\ [order_attendees_by: :registration]) do
    query =
      case(slug_or_id) do
        id when is_integer(id) -> [id: id, published: true]
        slug when is_binary(slug) -> [slug: slug, published: true]
      end

    Event
    |> Repo.get_by!(query)
    |> preload_event_assocs(opts)
  end

  def preload_event_assocs(%Event{} = event, opts \\ [order_attendees_by: :registration]) do
    attendee_query =
      case Keyword.get(opts, :order_attendees_by) do
        :registration ->
          from ea in EventAttendee, order_by: [asc: ea.inserted_at]

        :is_remote_and_full_name ->
          from ea in EventAttendee,
            join: u in assoc(ea, :user),
            order_by: [asc: ea.is_remote, asc: u.full_name]
      end

    sessions_query = from s in EventSession, order_by: s.begin

    event
    |> Repo.preload([:langs, :hosts, :last_live_session, sessions: sessions_query])
    |> Repo.preload(events_attendees: {attendee_query, [:user, :langs]})
  end

  @doc """
  Creates a event.

  ## Examples

      iex> create_event(%{field: value})
      {:ok, %Event{}}

      iex> create_event(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_event(attrs \\ %{}, opts \\ []) do
    %Event{}
    |> Event.changeset(attrs, opts)
    |> Repo.insert()
  end

  @doc """
  Updates a event.

  ## Examples

      iex> update_event(event, %{field: new_value})
      {:ok, %Event{}}

      iex> update_event(event, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_event(%Event{} = event, attrs) do
    event
    |> Event.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a event.

  ## Examples

      iex> delete_event(event)
      {:ok, %Event{}}

      iex> delete_event(event)
      {:error, %Ecto.Changeset{}}

  """
  def delete_event(%Event{} = event) do
    Repo.delete(event)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking event changes.

  ## Examples

      iex> change_event(event)
      %Ecto.Changeset{data: %Event{}}

  """
  def change_event(%Event{} = event, attrs \\ %{}) do
    langs = list_langs_by_id(attrs["lang_ids"])

    event
    |> Repo.preload(:langs)
    |> Event.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:langs, langs)
  end

  def update_event_slides_page_number(%Event{} = event, attrs) do
    event
    |> Event.slides_page_number_changeset(attrs)
    |> Repo.update()
  end

  def update_event_live(%Event{} = event, live?) do
    event
    |> Event.live_changeset(%{live: live?})
    |> Repo.update()
  end

  def get_event_pdf_url(%Event{slides_filename: filename}) when is_binary(filename) do
    static_path = "/uploads/events/slides/#{filename}"
    Phoenix.VerifiedRoutes.static_url(DevRoundWeb.Endpoint, static_path)
  end

  def get_event_pdf_url(%Event{}), do: nil

  def create_lang(attrs \\ %{}) do
    %Lang{}
    |> change_lang(attrs)
    |> Repo.insert()
  end

  def change_lang(%Lang{} = lang, attrs \\ %{}) do
    lang
    |> Lang.changeset(attrs)
  end

  def lang_icon_dir, do: Path.join(["uploads", "langs", "icon"])
  def event_slides_dir, do: Path.join(["uploads", "events", "slides"])

  def event_open_for_registration?(%Event{registration_deadline: registration_deadline}) do
    DateTime.compare(DateTime.utc_now(), registration_deadline) == :lt
  end

  def change_event_attendee(%EventAttendee{} = attendee, %Event{} = event, attrs, mode) do
    event = Repo.preload(event, :langs)
    langs_ids = attrs["lang_ids"]

    changeset =
      attendee
      |> Repo.preload([:langs, :event, :user])
      |> EventAttendee.registration_changeset(attrs, mode)

    changeset =
      if langs_ids != nil do
        langs = list_langs_by_id(attrs["lang_ids"])

        changeset
        |> Ecto.Changeset.put_assoc(:langs, langs)
      else
        changeset
      end

    changeset
    |> validate_event_attendee_langs(event)
  end

  def event_has_multiple_langs?(%Event{langs: langs}) do
    !Enum.empty?(tl(langs))
  end

  def create_event_attendee(
        %Event{} = event,
        %User{} = user,
        attrs \\ %{},
        mode \\ :self_registration
      ) do
    case can_change_event_attendee?(event, mode) do
      true ->
        change_event_attendee(%EventAttendee{}, event, attrs, mode)
        |> fill_event_attendee_initial(event, user)
        |> Repo.insert()

      _ ->
        {:error, :registration_closed}
    end
  end

  def update_event_attendee(%EventAttendee{} = attendee, attrs \\ %{}, mode \\ :self_registration) do
    attendee = Repo.preload(attendee, [:event, :user])

    case can_change_event_attendee?(attendee.event, mode) do
      true ->
        change_event_attendee(attendee, attendee.event, attrs, mode)
        |> Repo.update()

      _ ->
        {:error, :registration_closed}
    end
  end

  def delete_event_attendee(%EventAttendee{} = attendee, mode \\ :self_registration) do
    attendee = Repo.preload(attendee, [:event])

    case can_change_event_attendee?(attendee.event, mode) do
      true -> Repo.delete(attendee)
      _ -> {:error, :registration_closed}
    end
  end

  defp validate_event_attendee_langs(changeset, event) do
    langs = Ecto.Changeset.get_field(changeset, :langs)

    cond do
      is_nil(langs) || Enum.empty?(langs) ->
        Ecto.Changeset.add_error(changeset, :lang_ids, "Please select at least one language.")

      !Enum.empty?(langs -- event.langs) ->
        Ecto.Changeset.add_error(changeset, :lang_ids, "Invalid language for this event.")

      true ->
        changeset
    end
  end

  defp fill_event_attendee_initial(changeset, event, user) do
    changeset
    |> Ecto.Changeset.change(event: event, user: user, experience_level: user.experience_level)
  end

  defp can_change_event_attendee?(%Event{} = event, :self_registration = _mode),
    do: event_open_for_registration?(event)

  defp can_change_event_attendee?(%Event{} = _event, :host = _mode), do: true

  def list_langs_by_id(nil), do: []

  def list_langs_by_id(lang_ids) do
    Repo.all(from l in Lang, where: l.id in ^lang_ids)
  end

  def get_lang_by_name(name) do
    Repo.one(from l in Lang, where: l.name == ^name)
  end

  @doc """
  Gets a single lang by id.

  Raises `Ecto.NoResultsError` if the Lang does not exist.
  """
  def get_lang!(id), do: Repo.get!(Lang, id)

  alias DevRound.Events.EventSession

  @doc """
  Returns the list of event_session.

  ## Examples

      iex> list_event_session()
      [%EventSession{}, ...]

  """
  def list_event_session do
    Repo.all(EventSession)
  end

  @doc """
  Gets a single event_session.

  Raises `Ecto.NoResultsError` if the Event session does not exist.

  ## Examples

      iex> get_event_session!(123)
      %EventSession{}

      iex> get_event_session!(456)
      ** (Ecto.NoResultsError)

  """
  def get_event_session!(id), do: Repo.get!(EventSession, id)

  @doc """
  Creates a event_session.

  ## Examples

      iex> create_event_session(%{field: value})
      {:ok, %EventSession{}}

      iex> create_event_session(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_event_session(attrs \\ %{}) do
    %EventSession{}
    |> EventSession.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a event_session.

  ## Examples

      iex> update_event_session(event_session, %{field: new_value})
      {:ok, %EventSession{}}

      iex> update_event_session(event_session, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_event_session(%EventSession{} = event_session, attrs) do
    event_session
    |> EventSession.changeset(attrs)
    |> Repo.update()
  end

  def start_event_session(%Event{} = event, %EventSession{} = session) do
    Ecto.Multi.new()
    |> maybe_stop_last_live_session_multi_update(event, session)
    |> Ecto.Multi.update(:session, EventSession.start_changeset(session))
    |> Ecto.Multi.update(:event, event |> Ecto.Changeset.change(last_live_session_id: session.id))
    |> Repo.transaction()
  end

  defp maybe_stop_last_live_session_multi_update(
         %Ecto.Multi{} = multi,
         %Event{} = event,
         %EventSession{} = session
       ) do
    if is_nil(event.last_live_session) or event.last_live_session.id == session.id do
      multi
    else
      multi
      |> Ecto.Multi.update(
        :last_session,
        event.last_live_session |> EventSession.stop_changeset()
      )
    end
  end

  def stop_event_session(%EventSession{} = session) do
    session
    |> EventSession.stop_changeset()
    |> Repo.update()
  end

  def reset_event_session(%EventSession{} = session) do
    session
    |> Repo.preload(:teams)
    |> EventSession.reset_changeset()
    |> Repo.update()
  end

  @doc """
  Deletes a event_session.

  ## Examples

      iex> delete_event_session(event_session)
      {:ok, %EventSession{}}

      iex> delete_event_session(event_session)
      {:error, %Ecto.Changeset{}}

  """
  def delete_event_session(%EventSession{} = event_session) do
    Repo.delete(event_session)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking event_session changes.

  ## Examples

      iex> change_event_session(event_session)
      %Ecto.Changeset{data: %EventSession{}}

  """
  def change_event_session(%EventSession{} = event_session, attrs \\ %{}) do
    EventSession.changeset(event_session, attrs)
  end
end
