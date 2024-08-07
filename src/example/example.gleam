import gleam/dict
import gleam/option.{type Option}

pub type Person {
  Person(
    name: String,
    age: Int,
    pet: Option(Person),
    gross: dict.Dict(String, List(Option(dict.Dict(Int, Bool)))),
  )
}

pub type Pet {
  Pet(name: String)
}
