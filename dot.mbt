///|
fn dot_string(value : String) -> String {
  let out = StringBuilder()
  out.write_char('"')
  for char in value {
    match char {
      '"' => out.write_string("\\\"")
      '\\' => out.write_string("\\\\")
      '\n' => out.write_string("\\n")
      '\r' => out.write_string("\\r")
      _ => out.write_char(char)
    }
  }
  out.write_char('"')
  out.to_string()
}

///|
fn trace_uses_edge(
  trace : Array[TraceStep],
  from : String,
  to : String,
  action : String,
) -> Bool {
  for i in 1..<trace.length() {
    if trace[i - 1].state == from &&
      trace[i].state == to &&
      trace[i].via == Some(action) {
      return true
    }
  }
  false
}

///|
fn render_dot(model : Model, trace : Array[TraceStep]) -> String {
  let out = StringBuilder()
  out.write_string("digraph moonctl {\n  rankdir=LR;\n")
  for i in 0..<model.states.length() {
    let shape = if i == model.initial { "doublecircle" } else { "circle" }
    out.write_string(
      "  s\{i} [label=\{dot_string(model.states[i].id)}, shape=\{shape}];\n",
    )
  }
  for i in 0..<model.states.length() {
    for edge in model.outgoing[i] {
      let highlight = trace_uses_edge(
        trace,
        model.states[i].id,
        model.states[edge.to].id,
        edge.action,
      )
      let style = if highlight { ", color=red, penwidth=2" } else { "" }
      out.write_string(
        "  s\{i} -> s\{edge.to} [label=\{dot_string(edge.action)}\{style}];\n",
      )
    }
  }
  out.write_string("}\n")
  out.to_string()
}

///|
/// Export the explicit transition graph as Graphviz DOT. The initial state is
/// a double circle, and terminal stutter loops are shown explicitly.
pub fn Model::to_dot(self : Model) -> String {
  render_dot(self, [])
}

///|
/// Export the graph with a check result's witness or counterexample edges in
/// red. The report must have been produced from this model.
pub fn Model::to_dot_with_trace(self : Model, report : Report) -> String {
  render_dot(self, report.trace())
}
