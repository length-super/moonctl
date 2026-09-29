///|
/// Usage: moon run --target native cmd/main -- [--json] <graph.json> '<CTL formula>'
async fn main {
  let args = @env.args()
  let json_mode = args.length() == 4 && args[1] == "--json"
  if !(args.length() == 3 && args[1] != "--json") && !json_mode {
    println("usage: moonctl [--json] <graph.json> '<CTL formula>'")
    @sys.exit(2)
    return
  }
  let path = if json_mode { args[2] } else { args[1] }
  let formula_text = if json_mode { args[3] } else { args[2] }
  let data = @fs.read_file(path).text() catch {
    error => {
      emit_error("cannot read graph: \{error}", json_mode)
      @sys.exit(2)
      return
    }
  }
  let model = @moonctl.load_model_json(data) catch {
    error => {
      emit_error("invalid graph: \{Repr(error)}", json_mode)
      @sys.exit(2)
      return
    }
  }
  let formula = @moonctl.parse(formula_text) catch {
    error => {
      emit_error("invalid CTL formula: \{Repr(error)}", json_mode)
      @sys.exit(2)
      return
    }
  }
  let report = @moonctl.check(model, formula)
  if json_mode {
    println(
      Json::object({
        "formula": Json::string(formula_text),
        "report": report.to_json(),
      }).stringify(),
    )
    if !report.holds() {
      @sys.exit(1)
    }
    return
  }
  let verdict = if report.holds() { "PASS" } else { "FAIL" }
  println("\{verdict}: \{formula_text}")
  println(
    "states=\{report.state_count()} satisfying=\{report.satisfying_count()}",
  )
  if report.trace().length() > 0 {
    let path_kind = if report.loop_start() is Some(_) {
      "looping path"
    } else {
      "shortest path"
    }
    println("\{report.trace_role()} (\{path_kind}):")
    for step in report.trace() {
      match step.via {
        Some(action) => println("  --\{action}--> \{step.state}")
        None => println("  \{step.state}")
      }
    }
    match report.loop_start() {
      Some(index) => println("  repeat from step \{index} forever")
      None => ()
    }
  }
  if !report.holds() {
    @sys.exit(1)
  }
}

///|
fn emit_error(message : String, json_mode : Bool) -> Unit {
  if json_mode {
    println(Json::object({ "error": Json::string(message) }).stringify())
  } else {
    println(message)
  }
}
