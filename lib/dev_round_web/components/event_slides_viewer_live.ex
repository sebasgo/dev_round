defmodule DevRoundWeb.EventSlidesViewerLive do
  use DevRoundWeb, :live_component

  alias DevRound.Events

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-base-300 text-base rounded-lg shadow-lg overflow-hidden my-8">
      <div id="pdf-container" class="relative">
        <%= if @pdf_error do %>
          <div class="flex items-center justify-center w-full aspect-[16/9] bg-base-300">
            <div class="text-center opacity-70">
              <img src={~p"/images/broken-heart.svg"} class="inline w-[128px]" />
              <p class="mt-8">{@pdf_error}</p>
            </div>
          </div>
        <% else %>
          <%= if @pdf_url do %>
            <div
              id="pdf-viewer"
              phx-hook="PDFViewer"
              data-pdf-url={@pdf_url}
              data-pdf-page-number={@pdf_initial_page_number}
              class="aspect-[16/9]"
            >
              <!-- PDF.js viewer will be rendered here -->
              <div id="pdf-canvas-container" class="w-full">
                <canvas id="pdf-canvas"></canvas>
              </div>

              <div
                id="pdf-placeholder"
                class="absolute top-0 flex items-center justify-center w-full aspect-[16/9] bg-base-300"
              >
                <div class="text-center">
                  <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-primary mx-auto mb-4">
                  </div>
                  <p class="opacity-70">Loading PDF...</p>
                </div>
              </div>
            </div>
          <% else %>
            <div class="flex items-center justify-center w-full aspect-[16/9] bg-base-300">
              <p>
                This event doesn't have any slides uploaded yet.
              </p>
            </div>
          <% end %>
        <% end %>
        <!-- PDF Controls -->
        <div class="p-4 flex items-center justify-between bg-neutral">
          <div class="flex items-center space-x-4">
            <button id="prev-page" class="btn btn-primary" disabled={!@pdf_url || @pdf_error}>
              Previous
            </button>
            <button id="next-page" class="btn btn-primary" disabled={!@pdf_url || @pdf_error}>
              Next
            </button>
          </div>
          <div :if={@pdf_url && !@pdf_error} class="flex items-center space-x-4">
            <span class="text-sm">
              Page <span id="current-page">{@pdf_initial_page_number}</span>
              of <span id="total-pages">-</span>
            </span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def update(%{event: event}, socket) do
    {:ok, socket |> assign(:event, event) |> assign_pdf_fields()}
  end

  @impl true
  def handle_event("pdf_error", %{"error" => error}, socket) do
    {:noreply,
     socket
     |> assign(:pdf_error, error)}
  end

  @impl true
  def handle_event("pdf_page_turn", %{"page_number" => page_number}, socket)
      when is_integer(page_number) do
    %{event: event, pdf_url: url} = socket.assigns

    {:ok, _} =
      Events.update_event_slides_page_number(event, page_number)

    broadcast_page_turn(url, page_number)
    {:noreply, socket}
  end

  defmacro __using__(:relay_page_turn_events) do
    quote do
      def handle_info(
            %{topic: "event_slides", payload: %{url: url, page_number: page_number}},
            socket
          )
          when url == socket.assigns.pdf_url do
        IO.inspect("boo")
        {:noreply, push_event(socket, "pdf_viewer_page_turn", %{pageNumber: page_number})}
      end

      defp subscribe_to_page_turn_topic() do
        :ok = DevRoundWeb.Endpoint.subscribe("event_slides")
      end

      defp assign_pdf_url(socket) do
        %{event: event} = socket.assigns
        socket
        |> assign(:pdf_url, DevRoundWeb.EventSlidesViewerLive.get_pdf_url(event.slides_filename))
      end
    end
  end

  defp assign_pdf_fields(socket) do
    %{event: event} = socket.assigns

    socket
    |> assign(:pdf_url, get_pdf_url(event.slides_filename))
    |> assign(:pdf_initial_page_number, event.slides_page_number)
    |> assign_new(:pdf_error, fn -> nil end)
  end

  def get_pdf_url(slides_filename) when is_binary(slides_filename) do
    static_path = "/uploads/events/slides/#{slides_filename}"
    Phoenix.VerifiedRoutes.static_url(DevRoundWeb.Endpoint, static_path)
  end

  def get_pdf_url(_), do: nil

  defp broadcast_page_turn(url, page_number) do
    DevRoundWeb.Endpoint.broadcast_from(self(), "event_slides", "page_turn", %{
      url: url,
      page_number: page_number
    })
  end
end
