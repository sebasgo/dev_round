defmodule DevRoundWeb.Admin.EventLangAdmin do
  use Backpex.LiveResource,
    adapter_config: [
      schema: DevRound.Events.Lang,
      repo: DevRound.Repo,
      update_changeset: &DevRound.Events.Lang.changeset/3,
      create_changeset: &DevRound.Events.Lang.changeset/3
    ],
    layout: {DevRoundWeb.Layouts, :admin},
    pubsub: [
      name: DevRound.PubSub,
      topic: "event_langs",
      event_prefix: "event_lang_"
    ]


  @impl Backpex.LiveResource
  def singular_name, do: "Programming Language"

  @impl Backpex.LiveResource
  def plural_name, do: "Programming Languages"

  @impl Backpex.LiveResource
  def fields do
    [
      name: %{
        module: Backpex.Fields.Text,
        label: "Name"
      },
      icon_path: %{
        module: Backpex.Fields.Upload,
        label: "Icon",
        upload_key: :icon,
        accept: ~w(.png .svg),
        max_file_size: 512_000,
        put_upload_change: &put_upload_change/6,
        consume_upload: &consume_upload/4,
        remove_uploads: &remove_uploads/3,
        list_existing_files: &list_existing_files/1,
        render: fn
          %{value: value} = assigns when value == "" or is_nil(value) ->
            ~H"<p>{Backpex.HTML.pretty_value(@value)}</p>"
          assigns ->
            ~H'<img class="h-10 w-auto" src={file_url(@value)} />'
        end
      }
    ]
  end

  @impl Backpex.LiveResource
  def item_actions([_show, edit, delete]) do
    [edit, delete]
  end

  defp list_existing_files(%{icon_path: icon} = _item) when icon != "" and not is_nil(icon), do: [icon]
  defp list_existing_files(_item), do: []

  def put_upload_change(_socket, params, item, uploaded_entries, removed_entries, action) do
    existing_files = list_existing_files(item) -- removed_entries

    new_entries =
      case action do
        :validate ->
          elem(uploaded_entries, 1)

        :insert ->
          elem(uploaded_entries, 0)
      end

    files = existing_files ++ Enum.map(new_entries, fn entry -> file_name(entry) end)

    case files do
      [file] ->
        Map.put(params, "icon_path", file)

      [_file | _other_files] ->
        Map.put(params, "icon_path", "too_many_files")

      [] ->
        Map.put(params, "icon_path", nil)
    end
  end

   defp consume_upload(_socket, _item, %{path: path} = _meta, entry) do
    file_name = file_name(entry)
    dest = Path.join([:code.priv_dir(:dev_round), "static", upload_dir(), file_name])

    File.cp!(path, dest)

    {:ok, file_url(file_name)}
  end

  defp remove_uploads(_socket, _item, removed_entries) do
    for file <- removed_entries do
      path = Path.join([:code.priv_dir(:dev_round), "static", upload_dir(), file])
      File.rm!(path)
    end
  end

  defp file_url(file_name) do
    static_path = Path.join([upload_dir(), file_name])
    Phoenix.VerifiedRoutes.static_url(DevRoundWeb.Endpoint, "/" <> static_path)
  end

  defp file_name(entry) do
    [ext | _tail] = MIME.extensions(entry.client_type)
    "#{entry.uuid}.#{ext}"
  end

  defp upload_dir, do: Path.join(["uploads", "langs", "icon"])


end
