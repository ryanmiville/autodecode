import decode
import examples/user.{type User, User}

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
