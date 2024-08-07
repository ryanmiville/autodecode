import gleam/dict.{type Dict}
import gleam/option.{type Option}

pub type Person {
  Person(
    name: String,
    age: Int,
    pet: Option(Person),
    gross: Dict(String, List(Option(Dict(Int, Bool)))),
  )
}

pub type Pet {
  Pet(name: String)
}
