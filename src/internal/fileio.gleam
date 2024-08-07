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
  delete(filepath)
  create_directory(path(filepath))
  write(filepath, contents)
  fmt(filepath)
}

pub fn output_filepath(in filepath: String) -> String {
  string.replace(filepath, ".gleam", "/decode.gleam")
}

fn delete(filepath: String) {
  case simplifile.delete(filepath) {
    Ok(_) | Error(simplifile.Enoent) -> Nil
    Error(e) ->
      panic as {
        "failed to delete file: "
        <> filepath
        <> "\nreason: "
        <> simplifile.describe_error(e)
      }
  }
}

fn create_directory(path: String) {
  case simplifile.create_directory(path) {
    Ok(_) | Error(simplifile.Eexist) -> Nil
    Error(e) ->
      panic as {
        "failed to create directory: "
        <> path
        <> "\nreason: "
        <> simplifile.describe_error(e)
      }
  }
}

fn write(filepath: String, contents: String) {
  case simplifile.write(filepath, contents) {
    Ok(_) -> Nil
    Error(e) ->
      panic as {
        "Failed to write file: "
        <> filepath
        <> "\nreason: "
        <> simplifile.describe_error(e)
      }
  }
}

fn drop_last(l: List(a)) -> List(a) {
  case l {
    [] | [_] -> []
    [x, ..xs] -> [x, ..drop_last(xs)]
  }
}

fn path(filepath: String) -> String {
  string.split(filepath, "/")
  |> drop_last
  |> string.join("/")
}

fn fmt(filepath: String) {
  let format =
    shellout.command(run: "gleam", with: ["format", filepath], in: ".", opt: [])

  case format {
    Ok(_) -> Nil
    Error(#(_, msg)) ->
      panic as { "Failed to format file: " <> filepath <> "\nreason: " <> msg }
  }
}
