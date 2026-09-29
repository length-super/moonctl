///|
/// Serialize a check result for CI and other tools. State truth values use the
/// same index order as the model supplied to `check`.
pub fn Report::to_json(self : Report) -> Json {
  let trace : Array[Json] = []
  for step in self.trace {
    let via = match step.via {
      Some(action) => Json::string(action)
      None => Json::null()
    }
    trace.push(Json::object({ "state": Json::string(step.state), "via": via }))
  }
  let loop_start = match self.loop_start {
    Some(index) => Json::number(index.to_double())
    None => Json::null()
  }
  Json::object({
    "schema_version": Json::number(1.0),
    "holds": Json::boolean(self.holds),
    "state_count": Json::number(self.state_count.to_double()),
    "satisfying_count": Json::number(self.satisfying_count.to_double()),
    "satisfying_states": Json::array(self.satisfying.map(v => Json::boolean(v))),
    "trace_role": Json::string(self.trace_role),
    "trace": Json::array(trace),
    "loop_start": loop_start,
  })
}
