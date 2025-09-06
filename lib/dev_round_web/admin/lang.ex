defmodule DevRoundWeb.Admin.Lang do
  use DevRoundWeb.Admin.Upload, upload_dir: DevRound.Events.lang_icon_dir(), field: :icon_path

  use Backpex.LiveResource,
    adapter_config: [
      schema: DevRound.Events.Lang,
      repo: DevRound.Repo,
      update_changeset: &DevRound.Events.Lang.changeset/3,
      create_changeset: &DevRound.Events.Lang.changeset/3
    ],
    layout: {DevRoundWeb.Layouts, :admin},
    pubsub: [
      topic: "admin.langs"
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
end
