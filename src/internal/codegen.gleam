import gleam/dict.{type Dict}
import gleam/list
import gleam/string
import internal/parse

pub fn file_contents(
  module: String,
  to_generate types: List(parse.DecoderDefinition),
) -> String {
  let module_imports = generate_imports(module, types)
  let decoders = generate_decoders(types)

  module_imports <> "\n\n" <> string.join(decoders, "\n\n")
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

fn generate_imports(
  module: String,
  to_generate types: List(parse.DecoderDefinition),
) -> String {
  let module_imports =
    types
    |> list.map(fn(t) { t.type_name.name })
    |> imports

  let module_imports = "import " <> module <> ".{" <> module_imports <> "}"
  module_imports <> "\nimport decode"
}

fn generate_decoders(defs: List(parse.DecoderDefinition)) -> List(String) {
  let deps = defs |> list.flat_map(fn(d) { [d.type_name, ..d.dependencies] })
  let decs = dependencies_decoders(deps)
  list.map(defs, generate_decoder(_, decs))
}

fn generate_decoder(def: parse.DecoderDefinition, decs: Decoders) -> String {
  let function_name = def.function_name.name
  let type_name = def.type_name.name
  let parse.Constructor(parse.TypeName(name, _), ps) = def.constructor
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

    let assert Ok(dec) = dict.get(decs, type_name.name)

    "|> decode.field(\"" <> decode_name <> "\", " <> dec <> ")"
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

type Type =
  String

type Decoder =
  String

type Decoders =
  Dict(Type, Decoder)

fn built_ins() -> Decoders {
  dict.from_list([
    #("Int", "decode.int"),
    #("Float", "decode.float"),
    #("String", "decode.string"),
    #("BitArray", "decode.bit_array"),
    #("Dynamic", "decode.dynamic"),
    #("Bool", "decode.bool"),
    #("Int", "decode.int"),
  ])
}

pub fn dependencies_decoders(types: List(parse.TypeName)) -> Decoders {
  do_dependencies_decoders(built_ins(), types)
}

fn do_dependencies_decoders(
  decs: Decoders,
  types: List(parse.TypeName),
) -> Decoders {
  case types {
    [] -> decs
    [h] -> add_decoder(h, decs)
    [h, ..rest] -> do_dependencies_decoders(add_decoder(h, decs), rest)
  }
}

fn add_decoder(tpe: parse.TypeName, decs: Decoders) -> Decoders {
  case dict.get(decs, tpe.name) {
    Ok(_) -> decs
    _ -> {
      let #(key, value) = get_decoder(tpe, decs)
      dict.insert(decs, key, value)
    }
  }
}

fn get_decoder(tpe: parse.TypeName, decs: Decoders) -> #(Type, Decoder) {
  case dict.get(decs, tpe.name) {
    Ok(d) -> #(tpe.name, d)
    _ -> do_get_decoder(tpe, decs)
  }
}

fn do_get_decoder(tpe: parse.TypeName, decs: Decoders) -> #(Type, Decoder) {
  case tpe {
    parse.TypeName("List(" <> _, [p]) -> #(
      tpe.name,
      list(get_decoder(p, decs).1),
    )
    parse.TypeName("Option(" <> _, [p]) -> #(
      tpe.name,
      optional(get_decoder(p, decs).1),
    )
    parse.TypeName("Dict(" <> _, [a, b]) -> #(
      tpe.name,
      dict(get_decoder(a, decs).1, get_decoder(b, decs).1),
    )
    parse.TypeName(name, []) -> #(name, string.lowercase(name) <> "()")
    _ -> panic as "unsupported type"
  }
}

fn list(dec: Decoder) -> Decoder {
  "decode.list(" <> dec <> ")"
}

fn dict(key: Decoder, value: Decoder) -> Decoder {
  "decode.dict(" <> key <> ", " <> value <> ")"
}

fn optional(dec: Decoder) -> Decoder {
  "decode.optional(" <> dec <> ")"
}
