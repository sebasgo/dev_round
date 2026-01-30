defmodule DevRoundWeb.Admin.ResourceActions.AddUserAction do
  use Backpex.ResourceAction
  import Ecto.Changeset
  import Phoenix.LiveView
  import DevRound.Changeset

  @impl Backpex.ResourceAction
  def title, do: "Add User From LDAP"

  @impl Backpex.ResourceAction
  def label, do: "Add user from LDAP"

  # you can reuse Backpex fields irn the field definition
  @impl Backpex.ResourceAction
  def fields do
    [
      name: %{
        module: Backpex.Fields.Text,
        label: "User Name",
        type: :string
      },
      experience_level: %{
        module: Backpex.Fields.Number,
        label: "Experience Level",
        type: :integer
      }
    ]
  end

  @impl Backpex.ResourceAction
  def changeset(change, attrs, _metadata \\ []) do
    change
    # |> cast(attrs, %{name: :string, experience_level: :integer})
    |> cast(attrs, [:name, :experience_level])
    |> validate_required([:name, :experience_level], message: "Required.")
    |> validate_experience_level()
  end

  @impl Backpex.ResourceAction
  def handle(socket, data) do
    case DevRound.LDAP.lookup_user(data.name) do
      {:ok, user_data} ->
        user_data = Map.put(user_data, :experience_level, data.experience_level)
        {:ok, user} = DevRound.Accounts.upsert_user(user_data)
        {:ok, socket |> put_flash(:info, "User #{user.full_name} created.")}

      {:error, :user_not_found} ->
        {:ok, socket |> put_flash(:info, "User #{data.name} not found in LDAP directory.")}

      {:error, _} ->
        {:ok, socket |> put_flash(:info, "Error adding #{data.name}: internal error.")}
    end
  end
end
