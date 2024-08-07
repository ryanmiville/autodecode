import decode
import example/example.{type Person, type Pet, Person, Pet}

pub fn pet() -> decode.Decoder(Pet) {
  decode.into({
    use name <- decode.parameter
    Pet(name)
  })
  |> decode.field("name", decode.string)
}

pub fn person() -> decode.Decoder(Person) {
  decode.into({
    use name <- decode.parameter
    use age <- decode.parameter
    use pet <- decode.parameter
    use gross <- decode.parameter
    Person(name, age, pet, gross)
  })
  |> decode.field("name", decode.string)
  |> decode.field("age", decode.int)
  |> decode.field("pet", decode.optional(person()))
  |> decode.field(
    "gross",
    decode.dict(
      decode.string,
      decode.list(decode.optional(decode.dict(decode.int, decode.bool))),
    ),
  )
}
