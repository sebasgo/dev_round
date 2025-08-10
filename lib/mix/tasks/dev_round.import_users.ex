defmodule Mix.Tasks.DevRound.ImportUsers do
  use Mix.Task

  @shortdoc "Import users from JSON file"
  @impl Mix.Task
  def run([file_path]) do
    Mix.Task.run("app.start")
    DevRound.UserImport.run_import(file_path)
  end

  def run(_) do
    IO.puts("Usage: mix dev_round.import_users <file_path>")
  end
end
