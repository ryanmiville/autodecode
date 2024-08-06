import decode
import glance.{type CustomType, type Field, type Type, NamedType}
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import shellout
import simplifile

pub type User {
  User(name: String, email: String, is_admin: Bool)
}

/// Decode data of this shape into a `User` record.
///
/// {
///   "name": "Lucy",
///   "email": "lucy@example.com",
///   "is-admin": true
/// }
///
pub fn user_decoder() -> decode.Decoder(User) {
  decode.into({
    use name <- decode.parameter
    use email <- decode.parameter
    use is_admin <- decode.parameter
    User(name, email, is_admin)
  })
  |> decode.field("name", decode.string)
  |> decode.field("email", decode.string)
  |> decode.field("is-admin", decode.bool)
}

// type Param {
//   Param(name: String, type_name: String)
// }

type CaseConfig {
  CamelCase
  KebabCase
  SnakeCase
}

type Template {
  Template(
    function_name: FunctionName,
    type_name: TypeName,
    decode_parameters: List(DecodeParameter),
    constructor: Constructor,
    decode_fields: List(DecodeField),
  )
}

type FunctionName {
  FunctionName(name: String)
}

type TypeName {
  TypeName(name: String)
}

type Parameter {
  Parameter(name: String, type_name: TypeName)
}

type DecodeParameter {
  DecodeParameter(parameter: Parameter)
}

type Constructor {
  Constructor(name: TypeName, parameters: List(Parameter))
}

type DecodeField {
  DecodeField(parameter: Parameter, config: CaseConfig)
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

fn do_template(t: Template) -> String {
  let function_name = t.function_name.name
  let type_name = t.type_name.name
  let Constructor(TypeName(name), ps) = t.constructor
  let ps =
    ps
    |> list.map(fn(p) { p.name })
    |> string.join(", ")

  let constructor = name <> "(" <> ps <> ")"

  let decode_parameters =
    t.decode_parameters
    |> list.map(fn(dp) { "use " <> dp.parameter.name <> " <- decode.parameter" })
    |> string.join("\n")

  let df_string = fn(df: DecodeField) -> String {
    let DecodeField(Parameter(name, type_name), config) = df
    let decode_name = case config {
      CamelCase -> camel_case(name)
      KebabCase -> kebab_case(name)
      SnakeCase -> name
    }

    "|> decode.field(\""
    <> decode_name
    <> "\", decode."
    <> string.lowercase(type_name.name)
    <> ")"
  }

  let decode_fields =
    t.decode_fields |> list.map(df_string) |> string.join("\n")

  string.replace(template, "FUNCTION_NAME", function_name)
  |> string.replace("TYPE", type_name)
  |> string.replace("PARAMETERS", decode_parameters)
  |> string.replace("CONSTRUCTOR", constructor)
  |> string.replace("DECODE_FIELDS", decode_fields)
}

// fn param_string(param: Param) -> String {
//   "    use " <> param.name <> " <- decode.parameter"
// }

// // makes decode.Decoder(t)
// fn make_decoder(tpe: CustomType, config: CaseConfig) -> String {
//   let assert [variant] = tpe.variants
//   case tpe.name == variant.name {
//     False -> panic as "variant name does not match type name"
//     True -> Nil
//   }

//   let params = list.map(variant.fields, make_param)

//   let parameters =
//     params
//     |> list.map(param_string)
//     |> string.join("\n")

//   let constructor = constructor(variant.name, params)

//   let fields =
//     params
//     |> list.map(decode_field(_, config))
//     |> string.join("\n")

//   "pub fn "
//   <> string.lowercase(variant.name)
//   <> "_decoder() -> Decoder("
//   <> variant.name
//   <> ") {\n"
//   <> "  decode.into({\n"
//   <> parameters
//   <> "\n"
//   <> constructor
//   <> "\n  })\n"
//   <> fields
//   <> "\n}\n"
// }

fn make_decoder_template(tpe: CustomType, config: CaseConfig) -> String {
  let assert [variant] = tpe.variants
  case tpe.name == variant.name {
    False -> panic as "variant name does not match type name"
    True -> Nil
  }

  let function_name = FunctionName(string.lowercase(variant.name))
  let type_name = TypeName(variant.name)
  let parameters = list.map(variant.fields, make_parameter)
  let decode_parameters = parameters |> list.map(DecodeParameter)
  let constructor = Constructor(type_name, parameters)
  let decode_fields = parameters |> list.map(DecodeField(_, config))

  let t =
    Template(
      function_name: function_name,
      type_name: type_name,
      decode_parameters: decode_parameters,
      constructor: constructor,
      decode_fields: decode_fields,
    )
  do_template(t)
}

// fn decode_field(param: Param, config: CaseConfig) -> String {
//   let decode_name = case config {
//     CamelCase -> camel_case(param.name)
//     KebabCase -> kebab_case(param.name)
//     SnakeCase -> param.name
//   }

//   "  |> decode.field(\""
//   <> decode_name
//   <> "\", decode."
//   <> string.lowercase(param.type_name)
//   <> ")"
// }

// fn constructor(name: String, params: List(Param)) -> String {
//   let params =
//     params
//     |> list.map(fn(p) { p.name })
//     |> string.join(", ")

//   "    " <> name <> "(" <> params <> ")"
// }

fn make_parameter(field: Field(Type)) -> Parameter {
  let assert Some(name) = field.label
  let assert NamedType(type_name, None, []) = field.item

  Parameter(name, TypeName(type_name))
}

// fn make_param(field: Field(Type)) -> Param {
//   let assert Some(name) = field.label
//   let assert NamedType(type_name, None, []) = field.item

//   Param(name, type_name)
// }

fn camel_case(s: String) -> String {
  case string.split(s, "_") {
    [h, ..rest] -> h <> rest |> list.map(string.capitalise) |> string.concat
    _ -> s
  }
}

fn kebab_case(s: String) -> String {
  string.replace(s, each: "_", with: "-")
}

fn read_file(name) {
  case simplifile.read(name) {
    Ok(content) -> content
    _ -> panic as { "Failed to read file " <> name }
  }
}

fn generate_from_file_and_type(file: String, typ: String) {
  let content = read_file(file)
  let assert Ok(parsed) = glance.module(content)
  let assert Ok(custom_type) =
    parsed.custom_types
    |> list.find(fn(ct) {
      let glance.Definition(_, ct) = ct
      ct.name == typ
    })

  let path = string.replace(file, ".gleam", "")
  let module_path = string.replace(path, "./src/", "")

  let import_module =
    "import " <> module_path <> ".{type " <> typ <> ", " <> typ <> "}"
  let output =
    "import decode\n"
    <> import_module
    <> "\n"
    <> make_decoder_template(custom_type.definition, SnakeCase)

  let _ = simplifile.create_directory(path)
  let out_file = path <> "/decode.gleam"
  case simplifile.write(out_file, output) {
    Ok(_) -> Nil
    _ -> panic as { "Failed to write file " <> out_file }
  }

  fmt(out_file)
}

fn fmt(file: String) {
  let format =
    shellout.command(run: "gleam", with: ["format", file], in: ".", opt: [])

  case format {
    Ok(_) -> Nil
    _ -> panic as { "Failed to format file" <> file }
  }
}

pub fn main() {
  generate_from_file_and_type("./src/examples/user.gleam", "User")
}
