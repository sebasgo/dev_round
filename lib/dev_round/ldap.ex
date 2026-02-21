defmodule DevRound.LDAP do
  @moduledoc """
  LDAP authentication module for user authentication and lookup.

  Provides functionality to authenticate users against an LDAP directory
  and lookup user information for profile updates and synchronization.
  """

  require Logger

  @doc """
  Authenticates an user against the LDAP directory.
  Returns {:ok, user} on success, {:error, reason} on failure.
  """

  def authenticate(username, password) do
    case connect() do
      {:ok, ldap_conn} ->
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
    case connect() do
      {:ok, ldap_conn} ->
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
    case search_field(ldap_conn, "uid", username) do
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

  defp search_field(connection, field, value) do
    settings = Application.get_env(:exldap, :settings, [])
    search_timeout = settings |> Keyword.get(:search_timeout) || 0
    base = settings |> Keyword.get(:base)

    base_config = {:base, to_charlist(base)}
    scope = {:scope, :eldap.wholeSubtree()}
    filter = {:filter, :eldap.equalityMatch(to_charlist(field), value)}
    timeout = {:timeout, search_timeout}

    attributes =
      {:attributes, [~c"uid", ~c"mail", ~c"givenName", ~c"sn", ~c"memberOf", ~c"thumbnailPhoto"]}

    options = [base_config, scope, filter, timeout, attributes]

    Exldap.search(connection, options)
  end

  defp verify_credentials(ldap_conn, user_dn, password) do
    case Exldap.verify_credentials(ldap_conn, user_dn, to_charlist(password)) do
      :ok -> :ok
      {:error, _reason} -> {:error, :invalid_credentials}
    end
  end

  defp parse_attributes(attrs) do
    with {:ok, username} <- get_attribute(attrs, "uid", &parse_ldap_str_attr/1),
         {:ok, email} <- get_attribute(attrs, "mail", &parse_ldap_str_attr/1),
         {:ok, first_name} <- get_attribute(attrs, "givenName", &parse_ldap_str_attr/1),
         {:ok, last_name} <- get_attribute(attrs, "sn", &parse_ldap_str_attr/1) do
      avatar_data =
        case get_attribute(attrs, "thumbnailPhoto", &parse_ldap_bin_attr/1) do
          {:ok, data} -> data
          _ -> nil
        end

      group_dns =
        case get_attribute(attrs, "memberOf", &parse_ldap_str_list_attr/1) do
          {:ok, data} -> data
          _ -> []
        end

      {:ok,
       %{
         name: username,
         email: email,
         full_name: "#{first_name} #{last_name}",
         avatar: avatar_data,
         groups: Enum.map(group_dns, &parse_ldap_dn/1) |> MapSet.new()
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

  defp parse_ldap_bin_attr([bytes | _] = _attr) do
    bytes
    |> :binary.list_to_bin()
    |> to_string()
  end

  defp parse_ldap_str_attr([bytes | _] = _attr) do
    bytes
    |> :binary.list_to_bin()
    |> to_string()
  end

  defp parse_ldap_str_list_attr(attr) do
    attr
    |> Enum.map(&:binary.list_to_bin/1)
  end

  defp parse_ldap_dn(dn) do
    dn
    |> String.split(",")
    |> Enum.map(fn dn_comp -> dn_comp |> String.split("=", parts: 2) |> List.to_tuple() end)
    |> Enum.filter(fn {key, _value} -> String.downcase(key) == "cn" end)
    |> Enum.map(fn {_key, value} -> value end)
    |> hd()
  end
end
