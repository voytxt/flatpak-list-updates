import gleam/io
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import gleamyshell

type FlatpakApp {
  FlatpakApp(name: String, version: Option(String))
}

pub fn main() -> Nil {
  io.println("[1/3] getting app list...")
  let installed = parse_flatpak_command(["list"])

  io.println("[2/3] getting app updates...")
  let updates = parse_flatpak_command(["remote-ls", "--updates"])

  io.println("[3/3] calculating updates...\n")
  list.each(updates, fn(app_to_update) {
    let app_version =
      list.find(installed, fn(x) { x.name == app_to_update.name })
      |> option.from_result
      |> option.map(fn(x) { x.version })
      |> option.flatten

    io.println(
      app_to_update.name
      <> ": "
      <> option.unwrap(app_version, "?")
      <> " -> "
      <> option.unwrap(app_to_update.version, "?"),
    )
  })
}

fn parse_flatpak_command(args: List(String)) -> List(FlatpakApp) {
  args
  |> list.append(["--columns=application,version"])
  |> gleamyshell.execute("flatpak", ".", _)
  |> result.lazy_unwrap(fn() { panic })
  |> fn(x) { x.output }
  |> string.split("\n")
  |> list.map(fn(line) {
    case string.split(line, "\t") {
      [app] -> option.Some(FlatpakApp(app, option.None))
      [app, version] -> option.Some(FlatpakApp(app, option.Some(version)))
      _ -> {
        io.println("Skipping unrecognized app: " <> line)
        option.None
      }
    }
  })
  |> option.values
  |> list.filter(fn(x) { x.name != "" })
}
