defmodule DevRound.Events do
  @moduledoc """
  The Events context.
  """

  import Ecto.Query, warn: false
  alias DevRound.Repo

  alias DevRound.Events.Event
  alias DevRound.Events.Langs

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
    |> Repo.preload([:langs, :hosts, :attendees])
    |> Repo.preload([events_attendees: [:user, :langs]])
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

  def list_langs_by_id(nil), do: []
  def list_langs_by_id(lang_ids) do
    Repo.all(from l in Langs, where: l.id in ^lang_ids)
  end
end
