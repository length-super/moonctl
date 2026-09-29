///|
fn fixture_model() -> @moonctl.Model {
  let states : Array[@moonctl.State] = [
    { id: "start", labels: ["start"], },
    { id: "error", labels: ["error"], },
    { id: "waiting", labels: ["ok"], },
    { id: "done", labels: ["done"], },
  ]
  let edges : Array[@moonctl.Edge] = [
    { from: 0, to: 1, action: "bad", },
    { from: 0, to: 2, action: "good", },
    { from: 1, to: 1, action: "stuck", },
    { from: 2, to: 3, action: "finish", },
  ]
  match @moonctl.Model::new(states, edges, initial=0) {
    Ok(model) => model
    Err(_) => abort("fixture model should be valid")
  }
}

///|
test "CTL path quantifiers distinguish possible and inevitable outcomes" {
  let model = fixture_model()
  assert_true(@moonctl.check(model, @moonctl.parse("EX error")).holds())
  assert_true(!@moonctl.check(model, @moonctl.parse("AX error")).holds())
  assert_true(@moonctl.check(model, @moonctl.parse("EF done")).holds())
  assert_true(!@moonctl.check(model, @moonctl.parse("AF done")).holds())
  assert_true(@moonctl.check(model, @moonctl.parse("EG !done")).holds())
  assert_true(!@moonctl.check(model, @moonctl.parse("AG !error")).holds())
  assert_true(@moonctl.check(model, @moonctl.parse("E[true U done]")).holds())
  assert_true(!@moonctl.check(model, @moonctl.parse("A[true U done]")).holds())
}

///|
test "dead ends stutter for CTL total-path semantics" {
  let states : Array[@moonctl.State] = [{ id: "done", labels: ["done"], }]
  let model = match @moonctl.Model::new(states, [], initial=0) {
    Ok(m) => m
    Err(_) => abort("fixture model should be valid")
  }
  for formula in ["EX done", "AX done", "EG done", "AG done", "AF done"] {
    assert_true(@moonctl.check(model, @moonctl.parse(formula)).holds())
  }
  assert_true(!@moonctl.check(model, @moonctl.parse("AF missing")).holds())
}

///|
test "shortest paths explain safety failures and reachable goals" {
  let model = fixture_model()
  let failure = @moonctl.check(model, @moonctl.parse("AG !error"))
  assert_true(!failure.holds())
  assert_eq(failure.trace_role(), "counterexample")
  assert_eq(failure.trace().length(), 2)
  assert_eq(failure.trace()[0].state, "start")
  assert_eq(failure.trace()[1].state, "error")
  assert_eq(failure.trace()[1].via, Some("bad"))
  let success = @moonctl.check(model, @moonctl.parse("EF done"))
  assert_true(success.holds())
  assert_eq(success.trace_role(), "witness")
  assert_eq(success.trace().length(), 3)
  assert_eq(success.trace()[2].state, "done")
  assert_eq(success.trace()[2].via, Some("finish"))
}

///|
test "until requires its left condition on every prior state" {
  let model = fixture_model()
  assert_true(!@moonctl.check(model, @moonctl.parse("E[ok U done]")).holds())
  assert_true(
    @moonctl.check(model, @moonctl.parse("E[start | ok U done]")).holds(),
  )
}

///|
test "parser honors precedence and rejects invalid syntax" {
  let formula = @moonctl.parse("AG !error | EF done & start")
  assert_true(
    formula is Or(AG(Not(Atom("error"))), And(EF(Atom("done")), Atom("start"))),
  )
  try @moonctl.parse("AG (done") catch {
    ExpectedToken(")") => ()
    _ => fail("expected missing closing parenthesis")
  } noraise {
    _ => fail("invalid formula accepted")
  }
}

///|
test "model rejects invalid graph input" {
  let states : Array[@moonctl.State] = [
    { id: "same", labels: [], },
    { id: "same", labels: [], },
  ]
  assert_true(
    @moonctl.Model::new(states, [], initial=0) is Err(DuplicateState("same")),
  )
  let states2 : Array[@moonctl.State] = [{ id: "a", labels: [], }]
  assert_true(
    @moonctl.Model::new(
      states2,
      [{ from: 0, to: 2, action: "oops", }],
      initial=0,
    )
    is Err(InvalidEdge(0, 2)),
  )
}

///|
test "AF counterexample and EG witness expose a replayable cycle" {
  let model = fixture_model()
  let failure = @moonctl.check(model, @moonctl.parse("AF done"))
  assert_true(!failure.holds())
  assert_eq(failure.trace_role(), "counterexample")
  assert_eq(failure.loop_start(), Some(1))
  assert_eq(failure.trace().length(), 3)
  assert_eq(failure.trace()[1].state, "error")
  assert_eq(failure.trace()[2].via, Some("stuck"))
  let witness = @moonctl.check(model, @moonctl.parse("EG !done"))
  assert_true(witness.holds())
  assert_eq(witness.trace_role(), "witness")
  assert_eq(witness.loop_start(), Some(1))
  assert_eq(witness.trace()[2].state, "error")
}

///|
test "dead-end lasso includes the implicit stutter edge" {
  let states : Array[@moonctl.State] = [{ id: "waiting", labels: [], }]
  let model = match @moonctl.Model::new(states, [], initial=0) {
    Ok(m) => m
    Err(_) => abort("fixture model should be valid")
  }
  let failure = @moonctl.check(model, @moonctl.parse("AF done"))
  assert_eq(failure.loop_start(), Some(0))
  assert_eq(failure.trace().length(), 2)
  assert_eq(failure.trace()[1].via, Some("<stutter>"))
}

///|
test "JSON loader validates schema and graph before evaluation" {
  let source = "{\"initial\":0,\"states\":[{\"id\":\"start\",\"labels\":[\"safe\"]}],\"edges\":[]}"
  let model = @moonctl.load_model_json(source)
  assert_true(@moonctl.check(model, @moonctl.parse("AG safe")).holds())
  try @moonctl.load_model_json("not JSON") catch {
    InvalidJson => ()
    _ => fail("expected invalid JSON error")
  } noraise {
    _ => fail("invalid JSON accepted")
  }
  try
    @moonctl.load_model_json("{\"states\":[],\"edges\":[],\"initial\":0}")
  catch {
    InvalidGraph(EmptyStates) => ()
    _ => fail("expected invalid graph error")
  } noraise {
    _ => fail("empty graph accepted")
  }
  try
    @moonctl.load_model_json("{\"states\":[],\"edges\":[],\"initial\":0.5}")
  catch {
    WrongType("initial") => ()
    _ => fail("expected integer field error")
  } noraise {
    _ => fail("fractional index accepted")
  }
}

///|
test "universal and existential fixed points obey CTL dualities" {
  let model = fixture_model()
  for label in ["start", "error", "ok", "done", "missing"] {
    let always = @moonctl.check(model, @moonctl.parse("AG \{label}")).holds()
    let bad_reachable = @moonctl.check(model, @moonctl.parse("EF !\{label}")).holds()
    assert_eq(always, !bad_reachable)
    let inevitable = @moonctl.check(model, @moonctl.parse("AF \{label}")).holds()
    let escape = @moonctl.check(model, @moonctl.parse("EG !\{label}")).holds()
    assert_eq(inevitable, !escape)
  }
}
