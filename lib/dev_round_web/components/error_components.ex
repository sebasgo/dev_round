defmodule DevRoundWeb.ErrorComponents do
  use DevRoundWeb, :html

  attr :code, :integer, required: true
  attr :title, :string, required: true
  slot :inner_block

  def error_page(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en" data-theme="dark">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={get_csrf_token()} />
        <title>{@code} {@title}</title>
        <link rel="stylesheet" href={~p"/assets/css/app.css"} />
      </head>
      <body>
        <div class="card card-xl bg-black w-128 shadow-xl shadow-black mx-auto my-24">
          <div class="card-body items-center text-center">
            <h1 class="card-title">
              <span class="text-primary">{@code}</span> {@title}
            </h1>
            {render_slot(@inner_block)}
          </div>
          <figure>
            <img
              src={~p"/images/error.png"}
              alt="A rendering of an Apple MacBook which displays a pixelated broken heart which melts onto its keyboard."
            />
          </figure>
        </div>
      </body>
    </html>
    """
  end
end
