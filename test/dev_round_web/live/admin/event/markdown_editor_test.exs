defmodule DevRoundWeb.Admin.Event.MarkdownEditorTest do
  use DevRoundWeb.ConnCase, async: false

  import DevRound.EventsFixtures
  import Phoenix.LiveViewTest

  setup do
    admin = DevRound.AccountsFixtures.user_fixture(%{role: :admin})

    {:ok, admin} =
      DevRound.Accounts.User.upsert_changeset(admin, %{role: :admin}) |> DevRound.Repo.update()

    %{admin: admin}
  end

  test "renders the markdown editor with a preview and a view-mode switch", %{
    conn: conn,
    admin: admin
  } do
    event = event_fixture()
    conn = log_in_user(conn, admin)

    {:ok, view, _html} = live(conn, ~p"/admin/events/#{event.id}/edit")

    assert has_element?(view, "#markdown-editor-resource-form_body textarea#resource-form_body")
    assert has_element?(view, "#markdown-editor-resource-form_body [data-md-preview]")
    assert has_element?(view, "#markdown-editor-resource-form_body [data-md-mode='markdown']")
    assert has_element?(view, "#markdown-editor-resource-form_body [data-md-mode='split']")
    assert has_element?(view, "#markdown-editor-resource-form_body [data-md-mode='preview']")

    # the view mode storage is scoped per resource + field
    assert has_element?(
             view,
             "#markdown-editor-resource-form_body[data-md-storage-key='devround:markdown-editor-mode:DevRoundWeb.Admin.EventLive:body']"
           )

    assert has_element?(
             view,
             "#markdown-editor-resource-form_teaser[data-md-storage-key='devround:markdown-editor-mode:DevRoundWeb.Admin.EventLive:teaser']"
           )

    # the teaser uses the same editor
    assert has_element?(
             view,
             "#markdown-editor-resource-form_teaser textarea#resource-form_teaser"
           )
  end

  test "renders the current markdown in the preview", %{conn: conn, admin: admin} do
    event = event_fixture(%{body: "# Hello world"})
    conn = log_in_user(conn, admin)

    {:ok, view, _html} = live(conn, ~p"/admin/events/#{event.id}/edit")

    assert has_element?(
             view,
             "#markdown-editor-resource-form_body [data-md-preview] h1",
             "Hello world"
           )
  end

  test "updates the preview when the markdown changes", %{conn: conn, admin: admin} do
    event = event_fixture()
    conn = log_in_user(conn, admin)

    {:ok, view, _html} = live(conn, ~p"/admin/events/#{event.id}/edit")

    view
    |> form("#resource-form")
    |> render_change(%{
      "change" => %{"body" => "## Updated heading"},
      "_target" => ["change", "body"]
    })

    assert has_element?(
             view,
             "#markdown-editor-resource-form_body [data-md-preview] h2",
             "Updated heading"
           )
  end
end
