defmodule DevRound.Events do
  @moduledoc """
  The Events context.
  """

  import Ecto.Query, warn: false
  alias DevRound.Repo
  alias DevRound.Accounts.User
  alias DevRound.Events.Event
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

  def list_events(:upcoming) do
    from(e in Event, where: e.end > ^DateTime.utc_now() and e.published, order_by: [asc: e.begin])
    |> Repo.all()
  end

  def list_events(:past) do
    from(e in Event,
      where: e.end <= ^DateTime.utc_now() and e.published,
      order_by: [desc: e.begin]
    )
    |> Repo.all()
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

    attendee_query =
      case Keyword.get(opts, :order_attendees_by) do
        :registration ->
          from ea in EventAttendee, order_by: [asc: ea.inserted_at]

        :is_remote_and_full_name ->
          from ea in EventAttendee,
            join: u in assoc(ea, :user),
            order_by: [asc: ea.is_remote, asc: u.full_name]
      end

    Event
    |> Repo.get_by!(query)
    |> Repo.preload([:langs, :hosts])
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
  def create_event(attrs \\ %{}) do
    %Event{}
    |> Event.changeset(attrs)
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
