import glance.{type CustomType, type Field, type Type, CustomType, NamedType}
import gleam/list
import gleam/option.{None, Some}
import gleam/string

pub type DecoderDefinition {
  DecoderDefinition(
    function_name: FunctionName,
    type_name: TypeName,
    decode_parameters: List(DecodeParameter),
    constructor: Constructor,
    decode_fields: List(DecodeField),
    dependencies: List(TypeName),
  )
}

pub type FunctionName {
  FunctionName(name: String)
}

pub type TypeName {
  Basic(name: String)
  TList(name: String, type_parameter: TypeName)
  TOption(name: String, type_parameter: TypeName)
  TDict(name: String, key: TypeName, value: TypeName)
}

pub type Parameter {
  Parameter(name: String, type_name: TypeName)
}

pub type DecodeParameter {
  DecodeParameter(parameter: Parameter)
}

pub type Constructor {
  Constructor(name: TypeName, parameters: List(Parameter))
}

pub type DecodeField {
  DecodeField(parameter: Parameter)
}

pub fn decoder_definitions(code: String, types: List(String)) {
  custom_types(code, types)
  |> list.map(decoder_definition)
}

pub fn module(filepath: String) -> String {
  filepath
  |> string.replace("./src/", "")
  |> string.replace(".gleam", "")
}

fn decoder_definition(custom_type: CustomType) {
  let assert [variant] = custom_type.variants
  case custom_type.name == variant.name {
    False -> panic as "variant name does not match type name"
    True -> Nil
  }

  // TODO convert from camel to snake
  let function_name = FunctionName(string.lowercase(variant.name))
  let type_name = Basic(variant.name)
  let parameters = list.map(variant.fields, to_parameter)
  let decode_parameters = parameters |> list.map(DecodeParameter)
  let constructor = Constructor(type_name, parameters)
  let decode_fields = parameters |> list.map(DecodeField)
  let dependencies = parameters |> list.map(fn(p) { p.type_name })

  DecoderDefinition(
    function_name: function_name,
    type_name: type_name,
    decode_parameters: decode_parameters,
    constructor: constructor,
    decode_fields: decode_fields,
    dependencies: dependencies,
  )
}

fn custom_types(code: String, types: List(String)) -> List(CustomType) {
  let assert Ok(parsed) = glance.module(code)

  parsed.custom_types
  |> list.map(fn(d) { d.definition })
  |> list.filter(fn(ct) { list.contains(types, ct.name) })
}

fn to_parameter(field: Field(Type)) -> Parameter {
  let assert Some(name) = field.label
  let type_name = to_type_name(field.item)

  Parameter(name, type_name)
}

fn to_type_name(nt: Type) -> TypeName {
  case nt {
    NamedType(name, None, []) -> Basic(name)
    NamedType("List", None, [p]) -> {
      let param = to_type_name(p)
      let name = "List(" <> param.name <> ")"
      TList(name, param)
    }
    NamedType("Option", _, [p]) -> {
      let param = to_type_name(p)
      let name = "Option(" <> param.name <> ")"
      TOption(name, param)
    }
    NamedType("Dict", _, [k, v]) -> {
      let key = to_type_name(k)
      let value = to_type_name(v)
      let name = "Option(" <> key.name <> ", " <> value.name <> ")"
      TDict(name, key, value)
    }
    _ -> panic as { "unsupported type" <> string.inspect(nt) }
  }
}

fn to_type_names(types: List(Type)) -> List(TypeName) {
  case types {
    [h] -> [to_type_name(h)]
    [h, ..rest] -> [to_type_name(h), ..to_type_names(rest)]
    _ -> panic as { "unsupported type" <> string.inspect(types) }
  }
}
