///|
/// Reference semantics for tiny graphs. This deliberately enumerates simple
/// paths and detects repeated states instead of using the production fixed
/// point and predecessor algorithms.
fn reference_until(
  model : @moonctl.Model,
  state : Int,
  left : (Int) -> Bool,
  right : (Int) -> Bool,
  universal : Bool,
  seen : Array[Bool],
) -> Bool {
  if right(state) {
    return true
  }
  if !left(state) || seen[state] {
    return false
  }
  let visited = seen.copy()
  visited[state] = true
  if universal {
    for edge in model.successors(state) {
      if !reference_until(model, edge.to, left, right, true, visited) {
        return false
      }
    }
    true
  } else {
    for edge in model.successors(state) {
      if reference_until(model, edge.to, left, right, false, visited) {
        return true
      }
    }
    false
  }
}

///|
fn reference_globally(
  model : @moonctl.Model,
  state : Int,
  condition : (Int) -> Bool,
  existential : Bool,
  seen : Array[Bool],
) -> Bool {
  if !condition(state) {
    return false
  }
  if seen[state] {
    return true
  }
  let visited = seen.copy()
  visited[state] = true
  if existential {
    for edge in model.successors(state) {
      if reference_globally(model, edge.to, condition, true, visited) {
        return true
      }
    }
    false
  } else {
    for edge in model.successors(state) {
      if !reference_globally(model, edge.to, condition, false, visited) {
        return false
      }
    }
    true
  }
}

///|
fn reference_ctl(
  model : @moonctl.Model,
  formula : @moonctl.Formula,
  state : Int,
) -> Bool {
  match formula {
    True => true
    False => false
    Atom(label) => model.has_label(state, label)
    Not(inner) => !reference_ctl(model, inner, state)
    And(left, right) =>
      reference_ctl(model, left, state) && reference_ctl(model, right, state)
    Or(left, right) =>
      reference_ctl(model, left, state) || reference_ctl(model, right, state)
    EX(inner) => {
      for edge in model.successors(state) {
        if reference_ctl(model, inner, edge.to) {
          return true
        }
      }
      false
    }
    AX(inner) => {
      for edge in model.successors(state) {
        if !reference_ctl(model, inner, edge.to) {
          return false
        }
      }
      true
    }
    EF(inner) =>
      reference_until(
        model,
        state,
        _ => true,
        i => reference_ctl(model, inner, i),
        false,
        Array::make(model.state_count(), false),
      )
    AF(inner) =>
      reference_until(
        model,
        state,
        _ => true,
        i => reference_ctl(model, inner, i),
        true,
        Array::make(model.state_count(), false),
      )
    EG(inner) =>
      reference_globally(
        model,
        state,
        i => reference_ctl(model, inner, i),
        true,
        Array::make(model.state_count(), false),
      )
    AG(inner) =>
      reference_globally(
        model,
        state,
        i => reference_ctl(model, inner, i),
        false,
        Array::make(model.state_count(), false),
      )
    EU(left, right) =>
      reference_until(
        model,
        state,
        i => reference_ctl(model, left, i),
        i => reference_ctl(model, right, i),
        false,
        Array::make(model.state_count(), false),
      )
    AU(left, right) =>
      reference_until(
        model,
        state,
        i => reference_ctl(model, left, i),
        i => reference_ctl(model, right, i),
        true,
        Array::make(model.state_count(), false),
      )
  }
}

///|
fn reference_graph(
  size : Int,
  edge_mask : Int,
  label_mask : Int,
) -> @moonctl.Model {
  let states : Array[@moonctl.State] = []
  let edges : Array[@moonctl.Edge] = []
  let mut bit = 1
  for i in 0..<size {
    let labels : Array[String] = []
    if label_mask / bit % 2 == 1 {
      labels.push("p")
    }
    bit *= 2
    if label_mask / bit % 2 == 1 {
      labels.push("q")
    }
    bit *= 2
    states.push({ id: "s\{i}", labels, })
  }
  bit = 1
  for from in 0..<size {
    for to in 0..<size {
      if edge_mask / bit % 2 == 1 {
        edges.push({ from, to, action: "e\{from}_\{to}", })
      }
      bit *= 2
    }
  }
  match @moonctl.Model::new(states, edges, initial=0) {
    Ok(model) => model
    Err(_) => abort("enumerated graph should be valid")
  }
}

///|
fn replay_evidence(
  model : @moonctl.Model,
  formula : @moonctl.Formula,
  report : @moonctl.Report,
) -> Unit raise {
  let path = report.trace()
  let expected = match formula {
    EX(_) | EF(_) | EG(_) | EU(_, _) => report.holds()
    AX(_) | AF(_) | AG(_) | AU(_, _) => !report.holds()
    _ => false
  }
  if path.is_empty() {
    assert_true(!expected)
    assert_eq(report.trace_role(), "none")
    assert_eq(report.loop_start(), None)
    return
  }
  assert_true(expected)
  assert_eq(
    report.trace_role(),
    if report.holds() {
      "witness"
    } else {
      "counterexample"
    },
  )
  assert_eq(path[0].state, model.state_id(model.initial()).unwrap())
  assert_eq(path[0].via, None)
  let indices = [model.initial()]
  for i in 1..<path.length() {
    let mut next = -1
    for edge in model.successors(indices[i - 1]) {
      if model.state_id(edge.to) == Some(path[i].state) &&
        path[i].via == Some(edge.action) {
        next = edge.to
        break
      }
    }
    assert_true(next >= 0)
    indices.push(next)
  }
  let last = indices.length() - 1
  match report.loop_start() {
    Some(start) => {
      assert_true(start >= 0 && start < last)
      assert_eq(indices[last], indices[start])
    }
    None => ()
  }
  match formula {
    EX(inner) => {
      assert_eq(indices.length(), 2)
      assert_true(reference_ctl(model, inner, indices[last]))
    }
    AX(inner) => {
      assert_eq(indices.length(), 2)
      assert_true(!reference_ctl(model, inner, indices[last]))
    }
    EF(inner) => assert_true(reference_ctl(model, inner, indices[last]))
    AG(inner) => assert_true(!reference_ctl(model, inner, indices[last]))
    AF(inner) => {
      assert_true(report.loop_start() is Some(_))
      for index in indices {
        assert_true(!reference_ctl(model, inner, index))
      }
    }
    EG(inner) => {
      assert_true(report.loop_start() is Some(_))
      for index in indices {
        assert_true(reference_ctl(model, inner, index))
      }
    }
    EU(left, right) => {
      assert_true(reference_ctl(model, right, indices[last]))
      for i in 0..<last {
        assert_true(reference_ctl(model, left, indices[i]))
      }
    }
    AU(left, right) => {
      for i in 0..<last {
        assert_true(reference_ctl(model, left, indices[i]))
        assert_true(!reference_ctl(model, right, indices[i]))
      }
      match report.loop_start() {
        Some(_) => {
          assert_true(reference_ctl(model, left, indices[last]))
          assert_true(!reference_ctl(model, right, indices[last]))
        }
        None => {
          assert_true(!reference_ctl(model, left, indices[last]))
          assert_true(!reference_ctl(model, right, indices[last]))
        }
      }
    }
    _ => fail("unexpected trace for a Boolean formula")
  }
}

///|
test "independent path semantics match all CTL operators and replay traces" {
  let texts = [
    "true", "false", "p", "q", "!p", "p & q", "p | q", "EX p", "AX p", "EF q", "AF q",
    "EG p", "AG p", "E[p U q]", "A[p U q]", "EX (AF q)", "AG (EF p | AX q)", "A[EX p U EG q]",
  ]
  let formulas = texts.map(text => @moonctl.parse(text))
  for edge_mask in 0..<16 {
    for label_mask in 0..<16 {
      let model = reference_graph(2, edge_mask, label_mask)
      for formula in formulas {
        let report = @moonctl.check(model, formula)
        for state in 0..<2 {
          assert_eq(
            report.satisfies_at(state),
            Some(reference_ctl(model, formula, state)),
          )
        }
        replay_evidence(model, formula, report)
      }
    }
  }
  for sample in 0..<128 {
    let edge_mask = sample * 73 % 512
    let label_mask = sample * 37 % 64
    let model = reference_graph(3, edge_mask, label_mask)
    for formula in formulas {
      let report = @moonctl.check(model, formula)
      for state in 0..<3 {
        assert_eq(
          report.satisfies_at(state),
          Some(reference_ctl(model, formula, state)),
        )
      }
      replay_evidence(model, formula, report)
    }
  }
}
