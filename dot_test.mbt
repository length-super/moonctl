///|
test "DOT export escapes names and shows terminal stutter" {
  let states : Array[@moonctl.State] = [
    { id: "start\"line", labels: [], },
    { id: "done\\ok", labels: ["done"], },
  ]
  let edges : Array[@moonctl.Edge] = [{ from: 0, to: 1, action: "go\nnow", }]
  let model = match @moonctl.Model::new(states, edges, initial=0) {
    Ok(model) => model
    Err(_) => abort("valid DOT fixture")
  }
  let dot = model.to_dot()
  assert_true(dot.contains("s0 [label=\"start\\\"line\", shape=doublecircle]"))
  assert_true(dot.contains("s1 [label=\"done\\\\ok\", shape=circle]"))
  assert_true(dot.contains("s0 -> s1 [label=\"go\\nnow\"]"))
  assert_true(dot.contains("s1 -> s1 [label=\"<stutter>\"]"))
}

///|
test "DOT export highlights only the checked counterexample edge" {
  let states : Array[@moonctl.State] = [
    { id: "start", labels: [], },
    { id: "bad", labels: ["bad"], },
    { id: "good", labels: [], },
  ]
  let edges : Array[@moonctl.Edge] = [
    { from: 0, to: 1, action: "fail", },
    { from: 0, to: 2, action: "pass", },
  ]
  let model = match @moonctl.Model::new(states, edges, initial=0) {
    Ok(model) => model
    Err(_) => abort("valid DOT fixture")
  }
  let report = @moonctl.check(model, @moonctl.parse("AG !bad"))
  let dot = model.to_dot_with_trace(report)
  assert_true(dot.contains("s0 -> s1 [label=\"fail\", color=red, penwidth=2]"))
  assert_true(dot.contains("s0 -> s2 [label=\"pass\"]"))
}
