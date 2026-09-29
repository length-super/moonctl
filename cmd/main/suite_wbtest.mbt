///|
test "suite parser preserves source lines across comments and CRLF" {
  let source = "# payment safety\r\nAG !double_charge\r\n\r\n  AF completed  \r\n"
  match parse_suite(source) {
    Ok(cases) => {
      assert_eq(cases.length(), 2)
      assert_eq(cases[0].line, 2)
      assert_eq(cases[0].text, "AG !double_charge")
      assert_eq(cases[1].line, 4)
      assert_eq(cases[1].text, "AF completed")
    }
    Err(_) => fail("valid suite should parse")
  }
}

///|
test "suite parser rejects empty and malformed suites" {
  assert_true(parse_suite("# comment\n \n") is Err(EmptySuite))
  assert_true(parse_suite("AG safe\nE[true U\n") is Err(InvalidFormula(2, _)))
}
