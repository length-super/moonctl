///|
/// CTL formulas over state labels. Every temporal operator is path-quantified.
pub enum Formula {
  True
  False
  Atom(String)
  Not(Formula)
  And(Formula, Formula)
  Or(Formula, Formula)
  EX(Formula)
  AX(Formula)
  EF(Formula)
  AF(Formula)
  EG(Formula)
  AG(Formula)
  EU(Formula, Formula)
  AU(Formula, Formula)
} derive(Debug)

///|
pub extend Formula with Debug::{to_repr}

///|
pub(all) suberror ParseError {
  UnexpectedEnd
  UnexpectedToken(String)
  ExpectedToken(String)
  InvalidCharacter(Char)
} derive(Debug)

///|
pub extend ParseError with Debug::{to_repr}

///|
fn is_identifier_char(ch : Char) -> Bool {
  let c = ch.to_int()
  (c >= 65 && c <= 90) ||
  (c >= 97 && c <= 122) ||
  (c >= 48 && c <= 57) ||
  c == 95 ||
  c == 45 ||
  c == 46 ||
  c == 58
}

///|
fn tokenize(source : String) -> Array[String] raise ParseError {
  let tokens : Array[String] = []
  let mut word = ""
  for ch in source {
    let c = ch.to_int()
    if is_identifier_char(ch) {
      word = word + ch.to_string()
    } else {
      if word != "" {
        tokens.push(word)
        word = ""
      }
      if c == 32 || c == 9 || c == 10 || c == 13 {
        continue
      }
      if ch == '!' ||
        ch == '&' ||
        ch == '|' ||
        ch == '(' ||
        ch == ')' ||
        ch == '[' ||
        ch == ']' {
        tokens.push(ch.to_string())
      } else {
        raise InvalidCharacter(ch)
      }
    }
  }
  if word != "" {
    tokens.push(word)
  }
  tokens
}

///|
priv struct Parser {
  tokens : Array[String]
  mut pos : Int
}

///|
fn Parser::peek(self : Parser) -> String? {
  self.tokens.get(self.pos)
}

///|
fn Parser::take(self : Parser) -> String? {
  let token = self.peek()
  if token is Some(_) {
    self.pos += 1
  }
  token
}

///|
fn Parser::expect(self : Parser, expected : String) -> Unit raise ParseError {
  if self.take() == Some(expected) {
    ()
  } else {
    raise ExpectedToken(expected)
  }
}

///|
fn Parser::parse_or(self : Parser) -> Formula raise ParseError {
  let mut left = self.parse_and()
  while self.peek() == Some("|") {
    ignore(self.take())
    left = Or(left, self.parse_and())
  }
  left
}

///|
fn Parser::parse_and(self : Parser) -> Formula raise ParseError {
  let mut left = self.parse_unary()
  while self.peek() == Some("&") {
    ignore(self.take())
    left = And(left, self.parse_unary())
  }
  left
}

///|
fn Parser::parse_unary(self : Parser) -> Formula raise ParseError {
  match self.take() {
    None => raise UnexpectedEnd
    Some("!") => Not(self.parse_unary())
    Some("EX") => EX(self.parse_unary())
    Some("AX") => AX(self.parse_unary())
    Some("EF") => EF(self.parse_unary())
    Some("AF") => AF(self.parse_unary())
    Some("EG") => EG(self.parse_unary())
    Some("AG") => AG(self.parse_unary())
    Some("(") => {
      let result = self.parse_or()
      self.expect(")")
      result
    }
    Some("E") => self.parse_until(true)
    Some("A") => self.parse_until(false)
    Some("true") => True
    Some("false") => False
    Some(token) => Atom(token)
  }
}

///|
fn Parser::parse_until(
  self : Parser,
  existential : Bool,
) -> Formula raise ParseError {
  self.expect("[")
  let left = self.parse_or()
  self.expect("U")
  let right = self.parse_or()
  self.expect("]")
  if existential {
    EU(left, right)
  } else {
    AU(left, right)
  }
}

///|
pub fn parse(source : String) -> Formula raise ParseError {
  let tokens = tokenize(source)
  let parser = Parser::{ tokens, pos: 0, }
  let result = parser.parse_or()
  match parser.peek() {
    Some(token) => raise UnexpectedToken(token)
    None => result
  }
}
