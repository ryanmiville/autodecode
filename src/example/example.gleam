import gleam/dict
import gleam/option.{type Option}

pub type Person {
  Person(
    name: String,
    age: Int,
    pet: Option(PetName),
    gross_type: dict.Dict(String, List(Option(dict.Dict(Int, Bool)))),
  )
}

pub type PetName {
  PetName(name: String)
}
