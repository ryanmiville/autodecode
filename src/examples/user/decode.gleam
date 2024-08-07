import decode
import examples/user.{type Person, type User, Person, User}

pub fn person() -> decode.Decoder(Person) {
  decode.into({
    use name <- decode.parameter
    use age <- decode.parameter
    Person(name, age)
  })
  |> decode.field("name", decode.string)
  |> decode.field("age", decode.int)
}

pub fn user() -> decode.Decoder(User) {
  decode.into({
    use name <- decode.parameter
    use email <- decode.parameter
    use is_admin <- decode.parameter
    User(name, email, is_admin)
  })
  |> decode.field("name", decode.string)
  |> decode.field("email", decode.string)
  |> decode.field("is_admin", decode.bool)
}
