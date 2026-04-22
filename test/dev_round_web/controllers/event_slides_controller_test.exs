defmodule DevRoundWeb.EventSlidesControllerTest do
  use DevRoundWeb.ConnCase, async: true

  alias DevRound.Events
  alias DevRound.EventsFixtures

  @pdf_content "PDFCONTENT"

  setup %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    event = EventsFixtures.event_fixture(%{slides_filename: "test.pdf"})

    # Ensure slides directory exists and write test file
    priv_dir = :code.priv_dir(:dev_round)
    slides_dir = Path.join([priv_dir, Events.event_slides_dir()])
    File.mkdir_p!(slides_dir)
    File.write!(Path.join(slides_dir, "test.pdf"), @pdf_content)

    {:ok, conn: conn, event: event}
  end

  test "download triggers attachment header", %{conn: conn, event: event} do
    conn = get(conn, ~p"/events/#{event.slug}/slides/#{event.slides_filename}?download=1")
    assert response(conn, 200) == @pdf_content

    assert get_resp_header(conn, "content-disposition") == [
             "attachment; filename=\"#{event.slug}.pdf\""
           ]
  end

  test "controller without download param returns pdf without attachment header", %{
    conn: conn,
    event: event
  } do
    conn = get(conn, ~p"/events/#{event.slug}/slides/#{event.slides_filename}")
    assert response(conn, 200) == @pdf_content
    assert get_resp_header(conn, "content-disposition") == []
  end

  test "event with no slides raises error", %{
    conn: conn
  } do
    event = EventsFixtures.event_fixture()

    assert_raise(DevRoundWeb.NotFoundError, fn ->
      get(conn, ~p"/events/#{event.slug}/slides/foobar")
    end)
  end

  test "raises error for non-existing event", %{conn: conn} do
    assert_raise(Ecto.NoResultsError, fn ->
      get(conn, ~p"/events/foobar/slides/foobar")
    end)
  end

  test "raises error for unpublished event", %{conn: conn} do
    event = EventsFixtures.event_fixture(%{published: false})

    assert_raise(Ecto.NoResultsError, fn ->
      get(conn, ~p"/events/#{event}/slides/foobar")
    end)
  end
end
