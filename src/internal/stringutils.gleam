import gleam/list
import gleam/regex.{type Match, Match}
import gleam/string

// const kebab = "_([a-zA-Z0-9])"
// const camel = "(?!^)[A-Z]"

const snake = "-([a-zA-Z0-9])"

const pascal = "(^[A-Z])|[A-Z]"

pub fn pascal_to_snake(in string: String) -> String {
  let assert Ok(#(first, rest)) = string.pop_grapheme(string)
  string.lowercase(first) <> sub(rest, pascal, to_snake)
}

pub fn snake_to_camel(in string: String) -> String {
  sub(string, snake, to_camel)
}

pub fn snake_to_kebab(in string: String) -> String {
  sub(string, snake, to_kebab)
}

fn to_snake(match: Match) -> String {
  case match.content {
    "-" <> c | "_" <> c | c -> "_" <> string.lowercase(c)
  }
}

fn to_kebab(match: Match) -> String {
  case match.content {
    "-" <> c | "_" <> c | c -> "-" <> string.lowercase(c)
  }
}

fn to_camel(match: Match) -> String {
  case match.content {
    "-" <> c | "_" <> c | c -> "-" <> string.uppercase(c)
  }
}

fn sub(
  in string: String,
  each pattern: String,
  with substitute: fn(Match) -> String,
) -> String {
  let assert Ok(re) = regex.from_string(pattern)
  let matches = regex.scan(re, string)
  let replacements = list.map(matches, fn(m) { #(m.content, substitute(m)) })

  list.fold(replacements, string, fn(acc, replacement) {
    let #(p, s) = replacement
    string.replace(acc, p, s)
  })
}
