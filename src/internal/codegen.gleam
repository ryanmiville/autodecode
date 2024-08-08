import gleam/dict.{type Dict}
import gleam/list
import gleam/string
import internal/parse.{
  type DecodeField, type DecoderDefinition, type Parameter, type TypeName, Basic,
  Constructor, DecodeField, Parameter, TDict, TList, TOption,
}
import internal/stringutils

pub fn file_contents(
  module: String,
  types: List(DecoderDefinition),
  config: CaseConfig,
) -> String {
  let module_imports = generate_imports(module, types)
  let decoders = generate_decoders(types, config)

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
  to_generate types: List(DecoderDefinition),
) -> String {
  let module_imports =
    types
    |> list.map(fn(t) { t.type_name.name })
    |> imports

  let module_imports = "import " <> module <> ".{" <> module_imports <> "}"
  module_imports <> "\nimport decode"
}

fn generate_decoders(
  defs: List(DecoderDefinition),
  config: CaseConfig,
) -> List(String) {
  let deps = defs |> list.flat_map(fn(d) { [d.type_name, ..d.dependencies] })
  let decs = dependencies_decoders(deps)
  list.map(defs, generate_decoder(_, decs, config))
}

fn generate_decoder(
  def: DecoderDefinition,
  decs: Decoders,
  config: CaseConfig,
) -> String {
  let function_name = def.function_name.name
  let type_name = def.type_name.name
  let assert Constructor(Basic(name), ps) = def.constructor
  let ps =
    ps
    |> list.map(fn(p) { p.name })
    |> string.join(", ")

  let constructor = name <> "(" <> ps <> ")"

  let decode_parameters =
    def.decode_parameters
    |> list.map(fn(dp) { "use " <> dp.parameter.name <> " <- decode.parameter" })
    |> string.join("\n")

  let df_string = fn(df: DecodeField) -> String {
    let DecodeField(Parameter(name, type_name)) = df
    let decode_name = case config {
      CamelCase -> stringutils.snake_to_camel(name)
      KebabCase -> stringutils.snake_to_kebab(name)
      SnakeCase -> name
    }

    let assert Ok(dec) = dict.get(decs, type_name)

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

fn imports(types: List(String)) -> String {
  let with_type =
    list.map(types, fn(t) { "type " <> t })
    |> string.join(", ")

  let cons = types |> string.join(", ")

  with_type <> ", " <> cons
}

type Decoder =
  String

type Decoders =
  Dict(TypeName, Decoder)

fn built_ins() -> Decoders {
  dict.from_list([
    #(Basic("Int"), "decode.int"),
    #(Basic("Float"), "decode.float"),
    #(Basic("String"), "decode.string"),
    #(Basic("BitArray"), "decode.bit_array"),
    #(Basic("Dynamic"), "decode.dynamic"),
    #(Basic("Bool"), "decode.bool"),
    #(Basic("Int"), "decode.int"),
  ])
}

pub fn dependencies_decoders(types: List(TypeName)) -> Decoders {
  do_dependencies_decoders(built_ins(), types)
}

fn do_dependencies_decoders(decs: Decoders, types: List(TypeName)) -> Decoders {
  case types {
    [] -> decs
    [h] -> add_decoder(h, decs)
    [h, ..rest] -> do_dependencies_decoders(add_decoder(h, decs), rest)
  }
}

fn add_decoder(tpe: TypeName, decs: Decoders) -> Decoders {
  case dict.get(decs, tpe) {
    Ok(_) -> decs
    _ -> dict.insert(decs, tpe, get_decoder(tpe, decs))
  }
}

fn get_decoder(tpe: TypeName, decs: Decoders) -> Decoder {
  case dict.get(decs, tpe) {
    Ok(d) -> d
    _ -> do_get_decoder(tpe, decs)
  }
}

fn do_get_decoder(tpe: TypeName, decs: Decoders) -> Decoder {
  case tpe {
    TList(_, p) -> list(get_decoder(p, decs))
    TOption(_, p) -> optional(get_decoder(p, decs))
    TDict(_, k, v) -> dict(get_decoder(k, decs), get_decoder(v, decs))
    Basic(name) -> stringutils.pascal_to_snake(name) <> "()"
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

pub type CaseConfig {
  CamelCase
  KebabCase
  SnakeCase
}
