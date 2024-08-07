import gleam/dict.{type Dict}
import gleam/list
import gleam/string
import internal/parse

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

pub fn dependencies(defs: List(parse.DecoderDefinition)) -> List(parse.TypeName) {
  defs
  |> list.map(do_dependencies)
  |> list.flatten
}

fn do_dependencies(def: parse.DecoderDefinition) -> List(parse.TypeName) {
  let deps =
    def.decode_parameters
    |> list.map(fn(dp) { dp.parameter.type_name })

  [def.type_name, ..deps]
}

pub fn find_decoders(types: List(parse.TypeName)) -> Decoders {
  do_find_decoders(built_ins(), types)
}

fn do_find_decoders(decs: Decoders, types: List(parse.TypeName)) -> Decoders {
  case types {
    [] -> decs
    [h] -> add_decoder(h, decs)
    [h, ..rest] -> do_find_decoders(add_decoder(h, decs), rest)
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
  // let decs =
  //   decs
  //   |> add_decoder(key)
  //   |> add_decoder(value)

  "decode.dict(" <> key <> ", " <> value <> ")"
}

fn optional(dec: Decoder) -> Decoder {
  "decode.optional(" <> dec <> ")"
}
