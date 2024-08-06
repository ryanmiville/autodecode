import gleam/string
import shellout
import simplifile

pub fn read_file(filepath) {
  case simplifile.read(filepath) {
    Ok(content) -> content
    _ -> panic as { "Failed to read file " <> filepath }
  }
}

pub fn write_file(filepath: String, contents: String) {
  let path = path(filepath)
  let assert Ok(_) = simplifile.create_directory(path)
  case simplifile.write(filepath, contents) {
    Ok(_) -> Nil
    _ -> panic as { "Failed to write file " <> filepath }
  }
  fmt(filepath)
}

fn all_but_last(l: List(a)) -> List(a) {
  case l {
    [] | [_] -> []
    [x, ..xs] -> [x, ..all_but_last(xs)]
  }
}

fn path(filepath: String) -> String {
  string.split(filepath, "/")
  |> all_but_last
  |> string.join("/")
}

fn fmt(filepath: String) {
  let format =
    shellout.command(run: "gleam", with: ["format", filepath], in: ".", opt: [])

  case format {
    Ok(_) -> Nil
    _ -> panic as { "Failed to format file" <> filepath }
  }
}
