import Backpex.Router

defmodule DevRoundWeb.Router do
  use DevRoundWeb, :router

  import Phoenix.LiveDashboard.Router
  import DevRoundWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {DevRoundWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", DevRoundWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/", PageController, :home
    get "/avatar/:name/:avatar_hash", AvatarController, :show
    get "/lang-icon/:file_name", LangIconController, :show
    get "/uploads/events/slides/:file_name", EventSlidesController, :show

    live_session :main,
      on_mount: [{DevRoundWeb.UserAuth, :ensure_authenticated}] do
      live "/users/settings", UserSettingsLive, :edit
      live "/events", EventLive.Index, :index
      live "/events/:slug", EventLive.Show, :show
      live "/events/:slug/live", EventSlidesLive.Show, :show
      live "/events/:slug/registration/new", EventLive.Show, :new_registration
      live "/events/:slug/registration/edit", EventLive.Show, :edit_registration
      live "/events/:slug/hosting/lobby", HostingLobbyLive.Show, :show

      live "/events/:slug/hosting/lobby/registration/edit/:user_name",
           HostingLobbyLive.Show,
           :edit_registration

      live "/events/:slug/hosting/lecture", HostingLectureLive.Show, :show
      live "/events/:slug/hosting/session/:session_slug", HostingSessionLive.Show, :show
    end
  end

  scope "/admin", DevRoundWeb do
    pipe_through [:browser, :require_authenticated_user, :require_admin]

    backpex_routes()

    get "/", Admin.HomeController, :index

    live_session :admin,
      on_mount: [{DevRoundWeb.UserAuth, :ensure_authenticated}, Backpex.InitAssigns] do
      live_resources "/events", Admin.Event
      live_resources "/event_attendees", Admin.EventAttendees
      live_resources "/users", Admin.User
      live_resources "/langs", Admin.Lang
      live_resources "/team_names", Admin.TeamName
    end

    live_dashboard "/dashboard", metrics: DevRoundWeb.Telemetry
  end

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:dev_round, :dev_routes) do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", DevRoundWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/create_session", UserSessionController, :create

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{DevRoundWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/log_in", UserLoginLive, :new
    end
  end

  scope "/", DevRoundWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete
  end
end
