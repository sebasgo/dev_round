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
  def list_events do
    Repo.all(Event)
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
  def get_event!(id) do
    Event
    |> Repo.get_by!([id: id, published: true])
    |> Repo.preload([:langs, :hosts])
    |> Repo.preload([events_attendees: {from(a in EventAttendee, order_by: a.inserted_at), [:user, :langs]}])
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

  def change_event_attendee(%EventAttendee{} = attendee, %Event{} = event, %User{} = user, attrs \\ %{}) do
    event = Repo.preload(event, :langs)
    langs_ids = attrs["lang_ids"]
    changeset = attendee
    |> Repo.preload([:langs, :event, :user])
    |> EventAttendee.changeset(attrs)
    if langs_ids != nil do
      langs = list_langs_by_id(attrs["lang_ids"])
      changeset
      |> Ecto.Changeset.put_assoc(:langs, langs)
    else
      changeset
    end
    |> Ecto.Changeset.change(event: event, user: user, expierence_level: user.experience_level)
    |> validate_event_attendee_langs(event)
  end

  def create_event_attendee(%Event{} = event, %User{} = user, attrs \\ %{}) do
    change_event_attendee(%EventAttendee{}, event, user, attrs)
    |> Repo.insert()
  end

  def update_event_attendee(%EventAttendee{} = attendee, attrs \\ %{}) do
    attendee = Repo.preload(attendee, [:event, :user])
    change_event_attendee(attendee, attendee.event, attendee.user, attrs)
    |> Repo.update()
  end

  def delete_event_attendee(%EventAttendee{} = attendee) do
    Repo.delete(attendee)
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

  def list_langs_by_id(nil), do: []
  def list_langs_by_id(lang_ids) do
    Repo.all(from l in Lang, where: l.id in ^lang_ids)
  end
end
