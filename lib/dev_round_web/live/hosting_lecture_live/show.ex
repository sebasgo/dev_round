defmodule DevRoundWeb.HostingLectureLive.Show do
  use DevRoundWeb, :live_view
  import DevRoundWeb.HostingBase

  alias DevRound.Events
  alias DevRound.Events.Event

  @impl true
  def mount(_params, _session, socket) do
    DevRoundWeb.Endpoint.subscribe("admin.events")
    DevRoundWeb.Endpoint.subscribe("lectures")
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _, socket) do
    socket =
      socket
      |> assign(:slug, slug)
      |> update_assigns()

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({"updated", %Event{} = event}, socket) do
    if event.id == socket.assigns.event.id do
      if event.slug != socket.assigns.event.slug do
        {:noreply, push_patch(socket, to: ~p"/events/#{event}/hosting/lecture")}
      else
        {:noreply, update_assigns(socket)}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info(%{topic: "lectures", payload: %{url: url, page_number: page_number}}, socket) when url == socket.assigns.pdf_url do
    {:noreply, push_event(socket, "pdf_viewer_page_turn", %{pageNumber: page_number})}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("pdf_error", %{"error" => error}, socket) do
    {:noreply,
     socket
     |> put_flash(:error, "Error loading PDF: #{error}")}
  end

  @impl true
  def handle_event("pdf_page_turn", %{"page_number" => page_number}, socket) when is_integer(page_number) do
    %{event: event, pdf_url: url} = socket.assigns
    {:ok, _} = Events.update_event_slides_page_number(event, %{"slides_page_number" => page_number})
    broadcast_page_turn(url, page_number)
    {:noreply, socket}
  end

  defp update_assigns(socket) do
    socket
    |> assign_event()
    |> assign_team_names()
    |> ensure_current_user_is_host!()
    |> assign_pdf_fields()
    |> assign(:page_title, page_title(socket.assigns.live_action))
    |> assign_messages()
  end

  def assign_pdf_fields(socket) do
    %{event: event} = socket.assigns
    socket
    |> assign(:pdf_url, get_pdf_url(event.slides_filename))
    |> assign_new(:pdf_page_number, fn -> event.slides_page_number end)
  end

  defp page_title(:show), do: "Hosting Lecture"

  defp get_pdf_url(slides_filename) when is_binary(slides_filename) do
    static_path = "/uploads/events/slides/#{slides_filename}"
    Phoenix.VerifiedRoutes.static_url(DevRoundWeb.Endpoint, static_path)
  end

  defp get_pdf_url(_), do: nil

  defp broadcast_page_turn(url, page_number) do
    DevRoundWeb.Endpoint.broadcast_from(self(), "lectures", "page_turn", %{url: url, page_number: page_number})
  end
end
