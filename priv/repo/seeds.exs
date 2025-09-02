# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     DevRound.Repo.insert!(%DevRound.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias DevRound.Hosting

[
  "2b|!2b",
  "char *team_name",
  "keep::calm && code",
  "#define true false",
  "// TODO: Teamname",
  "camel_case",
  "return 42;",
  "Master's of Algo Lands",
  "Hawking's Hawks",
  "Did You Restart?",
  "99 Problems but Coding Ain't One",
  "The League of Extraordinary Guesses",
  "Chuck Norris Proved P=NP",
  "System Tron",
  "Boom Shaka Laka",
  "Legendary Noobs",
  "The Go Getters",
  "Codebrewers",
  "Byte Me",
  "Quality Control",
  "Xterm-inate",
  "Code Ninjas",
  "Blue Screens",
  "Pinky and the Brain",
  "Long Term Side Effect",
  "Scholars on the Loose",
  "Too Smart to Fail",
  "Algebra Lovers",
  "foobar",
  "Access Denied",
  "Synergy Slayers",
  "Luck Of The Draw",
  "One Hit Wonders",
  "Fizz Buzz",
  "Bug Apocalypse",
  "Lady Bugs",
  "Fully Developed",
  "The Bug Slayers",
  "Scared to Compile",
  "Hugs for Bugs",
  "We Push to Master",
  "The Dirty Bits",
  "Enemy of Syntax",
  "One and Zero",
  "The Pseudocodes",
  "Works for Me",
  "NaN",
  "None",
  "Partners in Code",
  "AbstractProblemFactory",
  "Magic Number Wizards",
  "The Binary Trio",
  "Upgrade Required",
  "Goto Fail",
  "Beyond Infinity"
]
|> Enum.map(fn name ->
  {:ok, _} = Hosting.create_team_name(%{name: name}, on_conflict: :nothing)
end)

[
  %{name: "Python", icon_path: "python.svg"},
  %{name: "C++", icon_path: "cpp.svg"},
  %{name: "Julia", icon_path: "julia.svg"},
  %{name: "Fortran", icon_path: "fortran.svg"},
  %{name: "Elixir", icon_path: "elixir.png"}
]
|> Enum.map(fn %{icon_path: src_icon_path} = attrs ->
  if DevRound.Events.get_lang_by_name(attrs.name) == nil do
    priv_path = :code.priv_dir(:dev_round)
    ext = Path.extname(src_icon_path)
    src_icon_path = Path.join([priv_path, "repo", "lang_icons", src_icon_path])
    dst_filename = "#{Ecto.UUID.generate()}.#{ext}"

    dst_icon_path =
      Path.join([priv_path, "static", DevRound.Events.lang_icon_dir(), dst_filename])

    File.cp!(src_icon_path, dst_icon_path)
    {:ok, _} = DevRound.Events.create_lang(%{attrs | icon_path: dst_filename})
  end
end)
