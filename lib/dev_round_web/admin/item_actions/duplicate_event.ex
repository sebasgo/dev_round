defmodule DevRoundWeb.Admin.ItemActions.DuplicateEvent do
  alias DevRound.Events
  use BackpexWeb, :item_action

  import Ecto.Changeset

  @impl Backpex.ItemAction
  def icon(assigns, _item) do
    ~H"""
    <Backpex.HTML.CoreComponents.icon
      name="hero-document-duplicate"
      class="h-5 w-5 cursor-pointer transition duration-75 hover:scale-110 hover:text-green-600"
    />
    """
  end

  @impl Backpex.ItemAction
  def base_schema(assigns) do
    [event | _] = assigns.selected_items
    data = %{title: event.title, begin_local: event.begin_local}
    types = %{title: :string, begin_local: :naive_datetime}
    {data, types}
  end

  @impl Backpex.ItemAction
  def fields do
    [
      title: %{
        module: Backpex.Fields.Text,
        label: "Title",
        type: :string
      },
      begin_local: %{
        module: Backpex.Fields.DateTime,
        label: "Begin",
        help_text: "End and session dates will be adjusted accordingly",
        type: :naive_datetime
      }
    ]
  end

  @impl Backpex.ItemAction
  def changeset(change, attrs, _meta) do
    change
    |> cast(attrs, [:title, :begin_local])
    |> validate_required([:title, :begin_local], message: "Required.")
    |> validate_title_or_begin_local_changed()
  end

  defp validate_title_or_begin_local_changed(change) do
    if Ecto.Changeset.changed?(change, :title) || Ecto.Changeset.changed?(change, :begin_local) do
      change
    else
      change
      |> add_error(:title, "One of title or begin must be changed.")
      |> add_error(:begin_local, "One of title or begin must be changed.")
    end
  end

  @impl Backpex.ItemAction
  def confirm(_assigns), do: "Enter a new title or begin to duplicate the event."

  @impl Backpex.ItemAction
  def label(_assigns, _item), do: "Duplicate"

  @impl Backpex.ItemAction
  def confirm_label(_assigns), do: "Duplicate"

  @impl Backpex.ItemAction
  def handle(socket, [item | _items], data) do
    item = item |> Events.preload_event_assocs()
    date_diff = calculate_date_diff(data.begin_local, item.begin_local)

    attrs =
      item
      |> Map.from_struct()
      |> Map.merge(data)
      |> shift_event_dates(date_diff)
      |> Map.put(:sessions, Enum.map(item.sessions, &process_session(&1, date_diff)))
      |> Map.put(:published, false)

    opts = [
      put_langs: item.langs,
      put_hosts: item.hosts
    ]

    case Events.create_event(attrs, opts) do
      {:ok, _item} ->
        {:ok, socket |> put_flash(:info, "Event has been duplicated successfully.")}

      {:error, _changeset} ->
        {:ok, socket |> put_flash(:error, "Error when duplicating event.")}
    end
  end

  defp calculate_date_diff(a, b) do
    a = DateTime.from_naive!(a, DevRound.Formats.time_zone())
    b = DateTime.from_naive!(b, DevRound.Formats.time_zone())
    DateTime.diff(a, b)
  end

  defp process_session(session, diff) do
    session
    |> Map.from_struct()
    |> Map.put(:begin_local, shift_local_date(session.begin_local, diff))
    |> Map.put(:end_local, shift_local_date(session.end_local, diff))
  end

  defp shift_event_dates(event_data, diff) do
    event_data
    |> Map.put(:end_local, shift_local_date(event_data.end_local, diff))
    |> Map.put(
      :registration_deadline_local,
      shift_local_date(event_data.registration_deadline_local, diff)
    )
  end

  defp shift_local_date(date, diff) do
    date
    |> DateTime.from_naive!(DevRound.Formats.time_zone())
    |> DateTime.add(diff)
    |> DateTime.to_naive()
  end
end
