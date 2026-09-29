///|
struct SuiteCase {
  line : Int
  text : String
  formula : @moonctl.Formula
}

///|
enum SuiteError {
  EmptySuite
  InvalidFormula(Int, @moonctl.ParseError)
} derive(Debug)

///|
fn parse_suite(source : String) -> Result[Array[SuiteCase], SuiteError] {
  let cases : Array[SuiteCase] = []
  let mut line_number = 0
  for raw in source.split("\n") {
    line_number += 1
    let text = raw.trim().to_owned()
    if text == "" || text.has_prefix("#") {
      continue
    }
    let formula = @moonctl.parse(text) catch {
      error => return Err(InvalidFormula(line_number, error))
    }
    cases.push({ line: line_number, text, formula, })
  }
  if cases.is_empty() {
    Err(EmptySuite)
  } else {
    Ok(cases)
  }
}

///|
fn run_suite(model : @moonctl.Model, source : String) -> Int {
  let cases = match parse_suite(source) {
    Ok(cases) => cases
    Err(EmptySuite) => {
      println("suite contains no CTL properties")
      return 2
    }
    Err(InvalidFormula(line, error)) => {
      println("invalid CTL formula on line \{line}: \{Repr(error)}")
      return 2
    }
  }
  let mut failures = 0
  for case in cases {
    let report = @moonctl.check(model, case.formula)
    let verdict = if report.holds() { "PASS" } else { "FAIL" }
    println("\{verdict} (line \{case.line}): \{case.text}")
    if !report.holds() {
      failures += 1
    }
  }
  println("suite: \{cases.length() - failures}/\{cases.length()} passed")
  if failures == 0 {
    0
  } else {
    1
  }
}
