///|
test "unreachable states preserve model order and ignore disconnected cycles" {
  let states : Array[@moonctl.State] = [
    { id: "start", labels: [], },
    { id: "orphan_a", labels: [], },
    { id: "done", labels: ["done"], },
    { id: "orphan_b", labels: [], },
  ]
  let edges : Array[@moonctl.Edge] = [
    { from: 0, to: 2, action: "finish", },
    { from: 1, to: 3, action: "next", },
    { from: 3, to: 1, action: "back", },
  ]
  let model = match @moonctl.Model::new(states, edges, initial=0) {
    Ok(model) => model
    Err(_) => abort("valid diagnostic fixture")
  }
  assert_eq(model.unreachable_states(), ["orphan_a", "orphan_b"])
  assert_true(@moonctl.check(model, @moonctl.parse("AF done")).holds())
}

///|
test "all reachable states yield an empty diagnostic" {
  let states : Array[@moonctl.State] = [
    { id: "start", labels: [], },
    { id: "done", labels: ["done"], },
  ]
  let edges : Array[@moonctl.Edge] = [{ from: 0, to: 1, action: "finish", }]
  let model = match @moonctl.Model::new(states, edges, initial=0) {
    Ok(model) => model
    Err(_) => abort("valid diagnostic fixture")
  }
  assert_eq(model.unreachable_states(), [])
}
