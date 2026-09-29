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

///|
test "report exposes formula truth at each state, including unreachable states" {
  let states : Array[@moonctl.State] = [
    { id: "start", labels: [], },
    { id: "goal", labels: ["goal"], },
    { id: "isolated", labels: ["goal"], },
  ]
  let edges : Array[@moonctl.Edge] = [{ from: 0, to: 1, action: "finish", }]
  let model = match @moonctl.Model::new(states, edges, initial=0) {
    Ok(m) => m
    Err(_) => abort("fixture model should be valid")
  }
  let report = @moonctl.check(model, @moonctl.parse("goal"))
  assert_true(!report.holds())
  assert_eq(report.satisfying_count(), 2)
  assert_eq(report.satisfies_at(0), Some(false))
  assert_eq(report.satisfies_at(1), Some(true))
  assert_eq(report.satisfies_at(2), Some(true))
  assert_eq(report.satisfies_at(3), None)
}

///|
test "next-step formulas show a concrete edge" {
  let model = fixture_model()
  let witness = @moonctl.check(model, @moonctl.parse("EX error"))
  assert_true(witness.holds())
  assert_eq(witness.trace_role(), "witness")
  assert_eq(witness.trace().length(), 2)
  assert_eq(witness.trace()[1].state, "error")
  assert_eq(witness.trace()[1].via, Some("bad"))
  let failure = @moonctl.check(model, @moonctl.parse("AX ok"))
  assert_true(!failure.holds())
  assert_eq(failure.trace_role(), "counterexample")
  assert_eq(failure.trace()[1].state, "error")
  assert_eq(failure.trace()[1].via, Some("bad"))
}

///|
test "until witness preserves left side before reaching goal" {
  let report = @moonctl.check(
    fixture_model(),
    @moonctl.parse("E[start | ok U done]"),
  )
  assert_true(report.holds())
  assert_eq(report.trace_role(), "witness")
  assert_eq(report.trace().length(), 3)
  assert_eq(report.trace()[0].state, "start")
  assert_eq(report.trace()[1].state, "waiting")
  assert_eq(report.trace()[2].state, "done")
  assert_eq(report.loop_start(), None)
}

///|
test "universal until failure distinguishes violation and infinite delay" {
  let model = fixture_model()
  let finite = @moonctl.check(model, @moonctl.parse("A[start U done]"))
  assert_true(!finite.holds())
  assert_eq(finite.trace_role(), "counterexample")
  assert_eq(finite.trace().length(), 2)
  assert_eq(finite.trace()[1].state, "error")
  assert_eq(finite.loop_start(), None)
  let infinite = @moonctl.check(model, @moonctl.parse("A[true U done]"))
  assert_true(!infinite.holds())
  assert_eq(infinite.trace_role(), "counterexample")
  assert_eq(infinite.loop_start(), Some(1))
  assert_eq(infinite.trace()[2].state, "error")
  assert_eq(infinite.trace()[2].via, Some("stuck"))
}

///|
test "until dualities hold over every two-state graph and labeling" {
  let universal = @moonctl.parse("A[p U q]")
  let universal_dual = @moonctl.parse("!(E[!q U (!p & !q)] | EG !q)")
  let existential = @moonctl.parse("E[p U q]")
  let existential_dual = @moonctl.parse("!(A[!q U (!p & !q)] | AG !q)")
  let powers = [1, 2, 4, 8]
  for edge_mask in 0..<16 {
    let edges : Array[@moonctl.Edge] = []
    for from in 0..<2 {
      for to in 0..<2 {
        if edge_mask / powers[from * 2 + to] % 2 == 1 {
          edges.push({ from, to, action: "step", })
        }
      }
    }
    for label_mask in 0..<16 {
      let states : Array[@moonctl.State] = []
      for i in 0..<2 {
        let labels : Array[String] = []
        if label_mask / powers[i * 2] % 2 == 1 {
          labels.push("p")
        }
        if label_mask / powers[i * 2 + 1] % 2 == 1 {
          labels.push("q")
        }
        states.push({ id: "s\{i}", labels, })
      }
      let model = match @moonctl.Model::new(states, edges, initial=0) {
        Ok(m) => m
        Err(_) => abort("enumerated model should be valid")
      }
      let a = @moonctl.check(model, universal)
      let a_dual = @moonctl.check(model, universal_dual)
      let e = @moonctl.check(model, existential)
      let e_dual = @moonctl.check(model, existential_dual)
      for i in 0..<2 {
        assert_eq(a.satisfies_at(i), a_dual.satisfies_at(i))
        assert_eq(e.satisfies_at(i), e_dual.satisfies_at(i))
      }
    }
  }
}

///|
test "fixed points propagate through a long acyclic chain" {
  let states : Array[@moonctl.State] = []
  let edges : Array[@moonctl.Edge] = []
  for i in 0..<256 {
    let labels = if i == 255 { ["goal"] } else { [] }
    states.push({ id: "s\{i}", labels, })
    if i > 0 {
      edges.push({ from: i - 1, to: i, action: "next", })
    }
  }
  let model = match @moonctl.Model::new(states, edges, initial=0) {
    Ok(m) => m
    Err(_) => abort("chain should be valid")
  }
  for formula in ["EF goal", "AF goal", "E[true U goal]", "A[true U goal]"] {
    assert_true(@moonctl.check(model, @moonctl.parse(formula)).holds())
  }
  assert_true(!@moonctl.check(model, @moonctl.parse("AG !goal")).holds())
  assert_true(!@moonctl.check(model, @moonctl.parse("EG !goal")).holds())
  let witness = @moonctl.check(model, @moonctl.parse("EF goal"))
  assert_eq(witness.trace().length(), 256)
  assert_eq(witness.trace()[255].state, "s255")
}

///|
test "JSON report preserves truth set and cycle metadata" {
  let report = @moonctl.check(fixture_model(), @moonctl.parse("AF done"))
  match report.to_json() {
    Object(fields) => {
      assert_eq(fields.get("schema_version"), Some(Json::number(1.0)))
      assert_eq(fields.get("holds"), Some(Json::boolean(false)))
      assert_eq(fields.get("state_count"), Some(Json::number(4.0)))
      assert_eq(fields.get("loop_start"), Some(Json::number(1.0)))
      match fields.get("trace") {
        Some(Array(steps)) => assert_eq(steps.length(), 3)
        _ => fail("trace must be a JSON array")
      }
    }
    _ => fail("report must be a JSON object")
  }
}
