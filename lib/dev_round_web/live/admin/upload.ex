defmodule DevRoundWeb.Admin.Upload do
  @moduledoc """
  Upload helper module for handling file uploads in Backpex resources.

  Provides macros for managing file uploads including:
  - Listing existing files
  - Handling upload changes
  - Consuming uploaded files
  - Removing uploads
  """

  defmacro __using__(opts) do
    quote do
      def list_existing_files(%{unquote(opts[:field]) => path} = _item)
          when path != "" and not is_nil(path),
          do: [path]

      def list_existing_files(_item), do: []

      def put_upload_change(_socket, params, item, uploaded_entries, removed_entries, action) do
        existing_files = list_existing_files(item) -- removed_entries

        new_entries =
          case action do
            :validate ->
              elem(uploaded_entries, 1)

            :insert ->
              elem(uploaded_entries, 0)
          end

        files = existing_files ++ Enum.map(new_entries, fn entry -> file_name(entry) end)

        case files do
          [file] ->
            Map.put(params, unquote(Atom.to_string(opts[:field])), file)

          [_file | _other_files] ->
            Map.put(params, unquote(Atom.to_string(opts[:field])), "too_many_files")

          [] ->
            Map.put(params, unquote(Atom.to_string(opts[:field])), nil)
        end
      end

      def consume_upload(_socket, _item, %{path: path} = _meta, entry) do
        file_name = file_name(entry)
        dest = Path.join([:code.priv_dir(:dev_round), upload_dir(), file_name])

        File.cp!(path, dest)

        {:ok, file_name}
      end

      def remove_uploads(_socket, _item, removed_entries) do
        for file <- removed_entries do
          path = Path.join([:code.priv_dir(:dev_round), upload_dir(), file])
          File.rm!(path)
        end
      end

      def file_name(entry) do
        [ext | _tail] = MIME.extensions(entry.client_type)
        "#{entry.uuid}.#{ext}"
      end

      defp upload_dir do
        unquote(opts[:upload_dir])
      end

      defp field do
        unquote(opts[:field])
      end
    end
  end
end
