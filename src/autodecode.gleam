import argv
import gleam/io
import gleam/string
import internal/codegen
import internal/fileio
import internal/parse

pub fn main() {
  case argv.load().arguments {
    [filepath, ..types] -> run(filepath, types)
    _ -> io.println("usage: gleam run -m autodecode <filepath> <Type1> <TypeN>")
  }
}

fn run(filepath: String, types: List(String)) {
  let code = fileio.read_file(filepath)

  let defs = parse.decoder_definitions(code, types, parse.SnakeCase)
  let module = parse.module(filepath)
  let contents = codegen.file_contents(module, defs)
  let output = fileio.output_filepath(filepath)
  fileio.write_file(output, contents)

  let msg =
    "wrote decoders for:\n\n"
    <> string.join(types, "\n")
    <> "\n\nto: "
    <> output

  io.println(msg)
}
