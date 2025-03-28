import Backpex.Router

defmodule DevRoundWeb.Router do
  use DevRoundWeb, :router

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
    pipe_through [:browser]

    get "/", PageController, :home
  end

  scope "/admin", DevRoundWeb do
    pipe_through :browser

    backpex_routes()

    live_session :default, on_mount: [Backpex.InitAssigns] do
      live_resources "/events", Admin.Event
      live_resources "/event_attendees", Admin.EventAttendees
      live_resources "/users", Admin.User
      live_resources "/langs", Admin.EventLangAdmin
    end
   end



  # Other scopes may use custom stacks.
  # scope "/api", DevRoundWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:dev_round, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: DevRoundWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", DevRoundWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{DevRoundWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", DevRoundWeb do
    pipe_through [:browser]

    live_session :require_authenticated_user,
      on_mount: [{DevRoundWeb.UserAuth, :ensure_authenticated}] do
      live "/users/settings", UserSettingsLive, :edit
      live "/events", EventLive.Index, :index
      live "/events/new", EventLive.Index, :new
      live "/events/:id/edit", EventLive.Index, :edit
      live "/events/:id", EventLive.Show, :show
      live "/events/:id/show/edit", EventLive.Show, :edit
    end
  end

  scope "/", DevRoundWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete
  end
end
