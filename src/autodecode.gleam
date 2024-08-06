import decode
import glance.{type CustomType, type Field, type Type, NamedType}
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/string

pub type User {
  User(name: String, email: String, is_admin: Bool)
}

const code = "
pub type User {
  User(name: String, email: String, is_admin: Bool)
}
"

// const code = "
// pub type Isb {
//   Isb(i: Int, s: String, b: Bool)
// }
// "

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

type Param {
  Param(name: String, type_name: String)
}

type CaseConfig {
  CamelCase
  KebabCase
  SnakeCase
}

type Template {
  Template(
    function_name: String,
    type_name: String,
    parameters: String,
    constructor: String,
    decode_fields: String,
  )
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
  let template = string.replace(template, "FUNCTION_NAME", t.function_name)
  let template = string.replace(template, "TYPE", t.type_name)
  let template = string.replace(template, "PARAMETERS", t.parameters)
  let template = string.replace(template, "CONSTRUCTOR", t.constructor)
  string.replace(template, "DECODE_FIELDS", t.decode_fields)
}

fn param_string(param: Param) -> String {
  "    use " <> param.name <> " <- decode.parameter"
}

// makes decode.Decoder(t)
fn make_decoder(tpe: CustomType, config: CaseConfig) -> String {
  let assert [variant] = tpe.variants
  case tpe.name == variant.name {
    False -> panic as "variant name does not match type name"
    True -> Nil
  }

  let params = list.map(variant.fields, make_param)

  let parameters =
    params
    |> list.map(param_string)
    |> string.join("\n")

  let constructor = constructor(variant.name, params)

  let fields =
    params
    |> list.map(decode_field(_, config))
    |> string.join("\n")

  "pub fn "
  <> string.lowercase(variant.name)
  <> "_decoder() -> Decoder("
  <> variant.name
  <> ") {\n"
  <> "  decode.into({\n"
  <> parameters
  <> "\n"
  <> constructor
  <> "\n  })\n"
  <> fields
  <> "\n}\n"
}

fn make_decoder_template(tpe: CustomType, config: CaseConfig) -> String {
  let assert [variant] = tpe.variants
  case tpe.name == variant.name {
    False -> panic as "variant name does not match type name"
    True -> Nil
  }

  let params = list.map(variant.fields, make_param)

  let parameters =
    params
    |> list.map(param_string)
    |> string.join("\n")

  let constructor = constructor(variant.name, params)

  let fields =
    params
    |> list.map(decode_field(_, config))
    |> string.join("\n")

  let t =
    Template(
      function_name: string.lowercase(variant.name) <> "_decoder",
      type_name: variant.name,
      parameters: parameters,
      constructor: constructor,
      decode_fields: fields,
    )
  do_template(t)
}

fn decode_field(param: Param, config: CaseConfig) -> String {
  let decode_name = case config {
    CamelCase -> camel_case(param.name)
    KebabCase -> kebab_case(param.name)
    SnakeCase -> param.name
  }

  "  |> decode.field(\""
  <> decode_name
  <> "\", decode."
  <> string.lowercase(param.type_name)
  <> ")"
}

fn constructor(name: String, params: List(Param)) -> String {
  let params =
    params
    |> list.map(fn(p) { p.name })
    |> string.join(", ")

  "    " <> name <> "(" <> params <> ")"
}

fn make_param(field: Field(Type)) -> Param {
  let assert Some(name) = field.label
  let assert NamedType(type_name, None, []) = field.item

  Param(name, type_name)
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

pub fn main() {
  let assert Ok(parsed) = glance.module(code)
  let assert [custom_type] = parsed.custom_types
  let definition = custom_type.definition
  io.print("snake_case:\n" <> make_decoder_template(definition, SnakeCase))
  io.print("camelCase:\n" <> make_decoder_template(definition, CamelCase))
  io.print("kebab-case:\n" <> make_decoder_template(definition, KebabCase))
}
