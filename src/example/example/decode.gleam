import decode
import example/example.{type Person, type PetName, Person, PetName}

pub fn pet_name() -> decode.Decoder(PetName) {
  decode.into({
    use name <- decode.parameter
    PetName(name)
  })
  |> decode.field("name", decode.string)
}

pub fn person() -> decode.Decoder(Person) {
  decode.into({
    use name <- decode.parameter
    use age <- decode.parameter
    use pet <- decode.parameter
    use gross_type <- decode.parameter
    Person(name, age, pet, gross_type)
  })
  |> decode.field("name", decode.string)
  |> decode.field("age", decode.int)
  |> decode.field("pet", decode.optional(pet_name()))
  |> decode.field(
    "gross_type",
    decode.dict(
      decode.string,
      decode.list(decode.optional(decode.dict(decode.int, decode.bool))),
    ),
  )
}
