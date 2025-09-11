defmodule DevRoundWeb.HostingLectureLive.Show do
  use DevRoundWeb, :live_view
  import DevRoundWeb.HostingBase

  alias DevRound.Events.Event
  alias DevRound.Hosting

  @impl true
  def mount(_params, _session, socket) do
    DevRoundWeb.Endpoint.subscribe("admin.events")
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"slug" => slug} = params, _, socket) do
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

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("pdf_error", %{"error" => error}, socket) do
    {:noreply,
     socket
     |> put_flash(:error, "Error loading PDF: #{error}")}
  end

  defp update_assigns(socket) do
    socket
    |> assign_event()
    |> assign_team_names()
    |> ensure_current_user_is_host!()
    |> assign_pdf_url()
    |> assign(:page_title, page_title(socket.assigns.live_action))
    |> assign_messages()
  end

  def assign_pdf_url(socket) do
    socket
    |> assign(:pdf_url, get_pdf_url(socket.assigns.event.slides_filename))
  end

  defp page_title(:show), do: "Hosting Lecture"

  defp get_pdf_url(slides_filename) when is_binary(slides_filename) do
    static_path = "/uploads/events/slides/#{slides_filename}"
    Phoenix.VerifiedRoutes.static_url(DevRoundWeb.Endpoint, static_path)
  end

  defp get_pdf_url(_), do: nil
end
