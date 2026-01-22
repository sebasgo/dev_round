defmodule DevRound.LDAP do
  @moduledoc """
  LDAP authentication module.
  """

  require Logger

  @doc """
  Authenticates an user against the LDAP directory.
  Returns {:ok, user} on success, {:error, reason} on failure.
  """

  def authenticate(username, password) do
    with {:ok, ldap_conn} <- connect() do
      try do
        with {:ok, result} <- find_user(ldap_conn, username),
             :ok <- verify_credentials(ldap_conn, result.object_name, password),
             {:ok, user} <- parse_attributes(result.attributes) do
          {:ok, user}
        else
          {:error, reason} = error ->
            Logger.warning("LDAP authentication failed for #{username}: #{inspect(reason)}")
            error
        end
      after
        Exldap.close(ldap_conn)
      end
    else
      {:error, reason} = error ->
        Logger.warning("LDAP connection failed for #{username}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Looks up an user in the LDAP directory.
  Returns {:ok, user} on success, {:error, reason} on failure.
  """
  def lookup_user(username) do
    with {:ok, ldap_conn} <- connect() do
      try do
        with {:ok, result} <- find_user(ldap_conn, username),
             {:ok, user} <- parse_attributes(result.attributes) do
          {:ok, user}
        else
          {:error, reason} = error ->
            Logger.warning("LDAP lookup failed for #{username}: #{inspect(reason)}")
            error
        end
      after
        Exldap.close(ldap_conn)
      end
    else
      {:error, reason} = error ->
        Logger.warning("LDAP lookup failed for #{username}: #{inspect(reason)}")
        error
    end
  end

  defp connect do
    case Exldap.connect() do
      {:ok, conn} -> {:ok, conn}
      {:error, reason} -> {:error, "Failed to connect to LDAP: #{inspect(reason)}"}
    end
  end

  defp find_user(ldap_conn, username, tries \\ 3) do
    case Exldap.search_field(ldap_conn, "uid", username) do
      {:ok, [result | _]} ->
        {:ok, result}

      {:ok, []} ->
        {:error, :user_not_found}

      # stupid hack when LDAP runs into an tcp timeout the first try
      {:error, {:gen_tcp_error, :timeout}} when tries > 0 ->
        find_user(ldap_conn, username, tries - 1)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp verify_credentials(ldap_conn, user_dn, password) do
    case Exldap.verify_credentials(ldap_conn, user_dn, to_charlist(password)) do
      :ok -> :ok
      {:error, _reason} -> {:error, :invalid_credentials}
    end
  end

  defp parse_attributes(attrs) do
    with {:ok, username} <- get_attribute(attrs, "uid", fn attr -> to_string(hd(attr)) end),
         {:ok, email} <- get_attribute(attrs, "mail", fn attr -> to_string(hd(attr)) end),
         {:ok, first_name} <-
           get_attribute(attrs, "givenName", fn attr -> to_string(hd(attr)) end),
         {:ok, last_name} <- get_attribute(attrs, "sn", fn attr -> to_string(hd(attr)) end) do
      avatar_data =
        case get_attribute(attrs, "thumbnailPhoto", fn attr -> :binary.list_to_bin(hd(attr)) end) do
          {:ok, data} -> data
          _ -> nil
        end

      {:ok,
       %{
         name: username,
         email: email,
         full_name: "#{first_name} #{last_name}",
         avatar_data: avatar_data
       }}
    else
      {:error, _reason} = error -> error
    end
  end

  defp get_attribute(attrs, key, convert_fun) do
    case List.keyfind(attrs, to_charlist(key), 0) do
      {_key, attr} -> {:ok, convert_fun.(attr)}
      nil -> {:error, "missing LDAP attribute #{key}"}
    end
  end
end
