import gleam/list
import gleam/string
import internal/parse

pub fn file_contents(
  module: String,
  to_generate types: List(parse.DecoderDefinition),
) -> String {
  let module_imports =
    types
    |> list.map(fn(t) { t.type_name.name })
    |> imports

  let module_imports = "import " <> module <> ".{" <> module_imports <> "}"
  let decoders =
    types
    |> list.map(generate_decoder)
    |> string.join("\n\n")

  module_imports <> "\nimport decode\n\n" <> decoders
}

const template = "
pub fn FUNCTION_NAME() -> decode.Decoder(TYPE) {
  decode.into({
    PARAMETERS
    CONSTRUCTOR
  })
  DECODE_FIELDS
}
"

fn generate_decoder(def: parse.DecoderDefinition) -> String {
  let function_name = def.function_name.name
  let type_name = def.type_name.name
  let parse.Constructor(parse.TypeName(name), ps) = def.constructor
  let ps =
    ps
    |> list.map(fn(p) { p.name })
    |> string.join(", ")

  let constructor = name <> "(" <> ps <> ")"

  let decode_parameters =
    def.decode_parameters
    |> list.map(fn(dp) { "use " <> dp.parameter.name <> " <- decode.parameter" })
    |> string.join("\n")

  let df_string = fn(df: parse.DecodeField) -> String {
    let parse.DecodeField(parse.Parameter(name, type_name), config) = df
    let decode_name = case config {
      parse.CamelCase -> camel_case(name)
      parse.KebabCase -> kebab_case(name)
      parse.SnakeCase -> name
    }

    "|> decode.field(\""
    <> decode_name
    <> "\", decode."
    <> string.lowercase(type_name.name)
    <> ")"
  }

  let decode_fields =
    def.decode_fields |> list.map(df_string) |> string.join("\n")

  string.replace(template, "FUNCTION_NAME", function_name)
  |> string.replace("TYPE", type_name)
  |> string.replace("PARAMETERS", decode_parameters)
  |> string.replace("CONSTRUCTOR", constructor)
  |> string.replace("DECODE_FIELDS", decode_fields)
}

fn camel_case(s: String) -> String {
  case string.split(s, "_") {
    [h, ..rest] -> h <> rest |> list.map(string.capitalise) |> string.concat
    _ -> s
  }
}

fn kebab_case(s: String) -> String {
  string.replace(s, each: "_", with: "-")
}

fn imports(types: List(String)) -> String {
  let with_type =
    list.map(types, fn(t) { "type " <> t })
    |> string.join(", ")

  let cons = types |> string.join(", ")

  with_type <> ", " <> cons
}
