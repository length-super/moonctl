///|
fn payment_next(state : @moonctl.State) -> Array[@moonctl.Transition] {
  match state.id {
    "new" => [{ to: { id: "charged_once", labels: [], }, action: "charge", }]
    "charged_once" =>
      [
        {
          to: { id: "charged_twice", labels: ["double_charge"], },
          action: "retry_without_idempotency",
        },
        { to: { id: "completed", labels: ["completed"], }, action: "confirm", },
      ]
    "charged_twice" =>
      [
        { to: { id: "completed", labels: ["completed"], }, action: "confirm", },
        {
          to: { id: "charged_twice", labels: ["double_charge"], },
          action: "retry_forever",
        },
      ]
    _ => []
  }
}

///|
fn main raise {
  let initial : @moonctl.State = { id: "new", labels: [], }
  match @moonctl.explore(initial, payment_next, max_states=2, max_edges=5) {
    Ok(Incomplete(limit, states, edges)) =>
      println(
        "small budget: incomplete \{Repr(limit)} states=\{states} edges=\{edges}",
      )
    _ => abort("small budget must not create a checkable model")
  }
  match @moonctl.explore(initial, payment_next, max_states=4, max_edges=5) {
    Ok(Complete(model)) => {
      let report = @moonctl.check(model, @moonctl.parse("AG !double_charge"))
      println(
        "full graph: holds=\{report.holds()} states=\{model.state_count()}",
      )
      for step in report.trace() {
        match step.via {
          Some(action) => println("  --\{action}--> \{step.state}")
          None => println("  \{step.state}")
        }
      }
    }
    _ => abort("full budget should produce a complete model")
  }
}
