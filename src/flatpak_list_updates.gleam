import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleamyshell.{CommandOutput}

type FlatpakApp {
  FlatpakApp(name: String, id: String, version: Option(String))
}

pub fn main() -> Nil {
  io.println("[1/4] refreshing appstream...")

  exec_flatpak_command(["update", "--appstream"])

  io.println("[2/4] getting app list...")

  let installed = {
    exec_flatpak_command(["list", "--columns=name,application,version"])
    |> parse_flatpak_applist_output
  }

  io.println("[3/4] getting app updates...")

  let updates = {
    exec_flatpak_command([
      "remote-ls", "--updates", "--columns=name,application,version",
    ])
    |> parse_flatpak_applist_output
  }

  io.println("[4/4] calculating updates...\n")

  updates
  |> list.each(fn(app) {
    let FlatpakApp(name:, version: latest_version, id:) = app

    let current_versions =
      installed
      |> list.filter(fn(app) { app.id == id })
      |> list.map(fn(app) { app.version |> option.unwrap("?") })

    io.println(
      name
      <> " ("
      <> id
      <> "): "
      <> case current_versions {
        [] -> "?"
        [a] -> a
        versions -> "[ " <> versions |> string.join(", ") <> " ]"
      }
      <> " -> "
      <> option.unwrap(latest_version, "?"),
    )
  })
}

fn exec_flatpak_command(args: List(String)) -> String {
  case gleamyshell.execute("flatpak", in: ".", args:) {
    Ok(CommandOutput(exit_code: 0, output:)) -> output

    Ok(CommandOutput(exit_code:, output:)) -> {
      panic as {
        "Command `"
        <> args |> string.join(" ")
        <> "` failed with exit code "
        <> exit_code |> int.to_string
        <> "; output: "
        <> output
      }
    }

    Error(reason) -> {
      panic as {
        "Failed to execute `flatpak "
        <> args |> string.join(" ")
        <> "`: "
        <> reason
      }
    }
  }
}

fn parse_flatpak_applist_output(flatpak_output: String) -> List(FlatpakApp) {
  flatpak_output
  |> string.split("\n")
  |> list.map(fn(line) {
    case string.split(line, "\t") {
      [name, id] -> {
        Some(FlatpakApp(name:, id:, version: None))
      }

      [name, id, version] -> {
        Some(FlatpakApp(name:, id:, version: Some(version)))
      }

      // last line
      [""] -> None

      _ -> panic as { "Cannot parse this line: " <> line }
    }
  })
  |> option.values
}
