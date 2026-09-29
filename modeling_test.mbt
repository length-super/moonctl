///|
test "named graph accepts IDs and resolves transitions" {
  let states : Array[@moonctl.State] = [
    { id: "queued", labels: ["waiting"], },
    { id: "done", labels: ["completed"], },
  ]
  let edges : Array[@moonctl.NamedEdge] = [
    { from: "queued", to: "done", action: "finish", },
  ]
  let model = match @moonctl.Model::from_named(states, edges, "queued") {
    Ok(model) => model
    Err(_) => abort("named graph should be valid")
  }
  assert_true(@moonctl.check(model, @moonctl.parse("AF completed")).holds())
  assert_eq(model.successors(0)[0].to, 1)
  assert_true(
    @moonctl.Model::from_named(states, edges, "missing")
    is Err(UnknownState("missing")),
  )
  let broken : Array[@moonctl.NamedEdge] = [
    { from: "queued", to: "missing", action: "finish", },
  ]
  assert_true(
    @moonctl.Model::from_named(states, broken, "queued")
    is Err(UnknownState("missing")),
  )
  let duplicate : Array[@moonctl.State] = [
    { id: "queued", labels: [], },
    { id: "queued", labels: ["other"], },
  ]
  assert_true(
    @moonctl.Model::from_named(duplicate, [], "queued")
    is Err(DuplicateName("queued")),
  )
}

///|
fn workflow_next(state : @moonctl.State) -> Array[@moonctl.Transition] {
  match state.id {
    "queued" =>
      [{ to: { id: "running", labels: ["active"], }, action: "start", }]
    "running" =>
      [{ to: { id: "done", labels: ["completed"], }, action: "finish", }]
    _ => []
  }
}

///|
test "bounded exploration checks only a fully discovered graph" {
  let initial : @moonctl.State = { id: "queued", labels: ["waiting"], }
  match @moonctl.explore(initial, workflow_next, max_states=3, max_edges=2) {
    Ok(Complete(model)) => {
      assert_eq(model.state_count(), 3)
      assert_true(@moonctl.check(model, @moonctl.parse("AF completed")).holds())
    }
    _ => fail("exact budgets should still allow a complete model")
  }
  assert_true(
    @moonctl.explore(initial, workflow_next, max_states=2, max_edges=2)
    is Ok(Incomplete(StateBudgetReached, 2, 1)),
  )
  assert_true(
    @moonctl.explore(initial, workflow_next, max_states=3, max_edges=1)
    is Ok(Incomplete(EdgeBudgetReached, 2, 1)),
  )
  assert_true(
    @moonctl.explore(initial, workflow_next, max_states=0, max_edges=2)
    is Err(InvalidBudget(0, 2)),
  )
}

///|
test "exploration refuses inconsistent labels for one state ID" {
  let initial : @moonctl.State = { id: "same", labels: ["safe"], }
  let next = fn(_state : @moonctl.State) -> Array[@moonctl.Transition] {
    [{ to: { id: "same", labels: ["unsafe"], }, action: "change", }]
  }
  assert_true(
    @moonctl.explore(initial, next, max_states=2, max_edges=2)
    is Err(ConflictingState("same")),
  )
}

///|
test "exploration treats dead ends as complete and cycles as bounded" {
  let initial : @moonctl.State = { id: "idle", labels: ["idle"], }
  let terminal = fn(_state : @moonctl.State) -> Array[@moonctl.Transition] {
    []
  }
  match @moonctl.explore(initial, terminal, max_states=1, max_edges=0) {
    Ok(Complete(model)) => {
      assert_eq(model.successors(0)[0].action, "<stutter>")
      assert_true(@moonctl.check(model, @moonctl.parse("AG idle")).holds())
    }
    _ => fail("terminal state must form a complete stuttering model")
  }
  let cycle = fn(state : @moonctl.State) -> Array[@moonctl.Transition] {
    [{ to: state, action: "tick", }]
  }
  match @moonctl.explore(initial, cycle, max_states=1, max_edges=1) {
    Ok(Complete(model)) => assert_eq(model.successors(0)[0].action, "tick")
    _ => fail("one-state cycle should fit exact budgets")
  }
}

///|
test "exploration protects stored labels from callback mutation" {
  let initial : @moonctl.State = { id: "safe", labels: ["safe"], }
  let next = fn(state : @moonctl.State) -> Array[@moonctl.Transition] {
    state.labels.push("tampered")
    []
  }
  match @moonctl.explore(initial, next, max_states=1, max_edges=0) {
    Ok(Complete(model)) => {
      assert_true(model.has_label(0, "safe"))
      assert_true(!model.has_label(0, "tampered"))
    }
    _ => fail("callback mutation must not change the model")
  }
}
