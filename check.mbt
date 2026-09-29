///|
/// A path from the initial state to an observed state. `via` is the transition
/// taken from the preceding step; it is None for the initial state.
pub(all) struct TraceStep {
  state : String
  via : String?
} derive(Debug)

///|
pub extend TraceStep with Debug::{to_repr}

///|
pub struct Report {
  holds : Bool
  state_count : Int
  satisfying_count : Int
  trace : Array[TraceStep]
  trace_role : String
  loop_start : Int?
}

///|
pub fn Report::holds(self : Report) -> Bool {
  self.holds
}

///|
pub fn Report::state_count(self : Report) -> Int {
  self.state_count
}

///|
pub fn Report::satisfying_count(self : Report) -> Int {
  self.satisfying_count
}

///|
/// Returns a defensive copy of the witness/counterexample available for the
/// top-level formula. Empty means no path is exposed. AG/EF paths are shortest;
/// AF/EG paths end with a repeated state, identified by `loop_start`.
pub fn Report::trace(self : Report) -> Array[TraceStep] {
  self.trace.copy()
}

///|
pub fn Report::trace_role(self : Report) -> String {
  self.trace_role
}

///|
/// If a trace ends by revisiting a state, this is the index of its first
/// occurrence. The final step closes the infinite loop.
pub fn Report::loop_start(self : Report) -> Int? {
  self.loop_start
}

///|
fn exists_next(model : Model, set : Array[Bool], state : Int) -> Bool {
  let edges = model.outgoing[state]
  if edges.is_empty() {
    return set[state]
  }
  for edge in edges {
    if set[edge.to] {
      return true
    }
  }
  false
}

///|
fn all_next(model : Model, set : Array[Bool], state : Int) -> Bool {
  let edges = model.outgoing[state]
  if edges.is_empty() {
    return set[state]
  }
  for edge in edges {
    if !set[edge.to] {
      return false
    }
  }
  true
}

///|
fn evaluate(model : Model, formula : Formula) -> Array[Bool] {
  let n = model.states.length()
  match formula {
    True => Array::make(n, true)
    False => Array::make(n, false)
    Atom(label) => Array::makei(n, i => model.has_label(i, label))
    Not(inner) => evaluate(model, inner).map(v => !v)
    And(left, right) => {
      let a = evaluate(model, left)
      let b = evaluate(model, right)
      Array::makei(n, i => a[i] && b[i])
    }
    Or(left, right) => {
      let a = evaluate(model, left)
      let b = evaluate(model, right)
      Array::makei(n, i => a[i] || b[i])
    }
    EX(inner) => {
      let s = evaluate(model, inner)
      Array::makei(n, i => exists_next(model, s, i))
    }
    AX(inner) => {
      let s = evaluate(model, inner)
      Array::makei(n, i => all_next(model, s, i))
    }
    EF(inner) => {
      let s = evaluate(model, inner)
      least_fixpoint(model, s, None, true)
    }
    AF(inner) => {
      let s = evaluate(model, inner)
      least_fixpoint(model, s, None, false)
    }
    EG(inner) => {
      let s = evaluate(model, inner)
      greatest_fixpoint(model, s, true)
    }
    AG(inner) => {
      let s = evaluate(model, inner)
      greatest_fixpoint(model, s, false)
    }
    EU(left, right) => {
      let a = evaluate(model, left)
      let b = evaluate(model, right)
      least_fixpoint(model, b, Some(a), true)
    }
    AU(left, right) => {
      let a = evaluate(model, left)
      let b = evaluate(model, right)
      least_fixpoint(model, b, Some(a), false)
    }
  }
}

///|
/// Least fixed point for F and U. `condition` is None for F.
fn least_fixpoint(
  model : Model,
  terminal : Array[Bool],
  condition : Array[Bool]?,
  existential : Bool,
) -> Array[Bool] {
  let result = terminal.copy()
  let mut changed = true
  while changed {
    changed = false
    for i in 0..<result.length() {
      if result[i] {
        continue
      }
      let allowed = match condition {
        Some(c) => c[i]
        None => true
      }
      if allowed &&
        (if existential {
          exists_next(model, result, i)
        } else {
          all_next(model, result, i)
        }) {
        result[i] = true
        changed = true
      }
    }
  }
  result
}

///|
/// Greatest fixed point for G.
fn greatest_fixpoint(
  model : Model,
  condition : Array[Bool],
  existential : Bool,
) -> Array[Bool] {
  let result = condition.copy()
  let mut changed = true
  while changed {
    changed = false
    for i in 0..<result.length() {
      if result[i] &&
        !(if existential {
          exists_next(model, result, i)
        } else {
          all_next(model, result, i)
        }) {
        result[i] = false
        changed = true
      }
    }
  }
  result
}

///|
/// BFS returns a shortest path; edge declaration order breaks equal-length ties.
fn shortest_path(model : Model, target : Array[Bool]) -> Array[TraceStep] {
  let n = model.states.length()
  let seen = Array::make(n, false)
  let parent = Array::make(n, -1)
  let action = Array::make(n, "")
  let queue = [model.initial]
  seen[model.initial] = true
  let mut head = 0
  let mut found = -1
  while head < queue.length() {
    let current = queue[head]
    head += 1
    if target[current] {
      found = current
      break
    }
    for edge in model.outgoing[current] {
      if !seen[edge.to] {
        seen[edge.to] = true
        parent[edge.to] = current
        action[edge.to] = edge.action
        queue.push(edge.to)
      }
    }
  }
  if found == -1 {
    return []
  }
  let reverse : Array[Int] = []
  let mut cursor = found
  while cursor != -1 {
    reverse.push(cursor)
    cursor = parent[cursor]
  }
  let path : Array[TraceStep] = []
  for i in 0..<reverse.length() {
    let index = reverse[reverse.length() - 1 - i]
    let via = if i == 0 { None } else { Some(action[index]) }
    path.push({ state: model.states[index].id, via, })
  }
  path
}

///|
/// Construct an ultimately periodic path that stays in `allowed`. For AF
/// failures or EG successes, fixed-point semantics guarantees a successor in
/// that set. An implicit self-loop handles a dead-end state.
fn lasso_path(model : Model, allowed : Array[Bool]) -> (Array[TraceStep], Int) {
  let seen = Array::make(model.states.length(), -1)
  let path : Array[TraceStep] = []
  let mut current = model.initial
  let mut via : String? = None
  while true {
    path.push({ state: model.states[current].id, via, })
    if seen[current] != -1 {
      return (path, seen[current])
    }
    seen[current] = path.length() - 1
    let mut next = -1
    let mut next_action = ""
    for edge in model.successors(current) {
      if allowed[edge.to] {
        next = edge.to
        next_action = edge.action
        break
      }
    }
    // The call sites only pass fixed-point sets closed under a chosen edge.
    if next == -1 {
      abort("lasso set has no successor")
    }
    current = next
    via = Some(next_action)
  }
  // Every path in a finite graph repeats a state.
  (path, 0)
}

///|
/// Evaluate a CTL formula at the model's initial state.
/// For top-level `AG` failures and `EF` successes, includes a shortest path.
pub fn check(model : Model, formula : Formula) -> Report {
  let result = evaluate(model, formula)
  let holds = result[model.initial]
  let mut satisfying_count = 0
  for value in result {
    if value {
      satisfying_count += 1
    }
  }
  let (trace, trace_role, loop_start) = match formula {
    AG(inner) if !holds => {
      let safe = evaluate(model, inner)
      (shortest_path(model, safe.map(v => !v)), "counterexample", None)
    }
    EF(inner) if holds => {
      let goal = evaluate(model, inner)
      (shortest_path(model, goal), "witness", None)
    }
    AF(_) if !holds => {
      let (path, loop_start) = lasso_path(model, result.map(v => !v))
      (path, "counterexample", Some(loop_start))
    }
    EG(_) if holds => {
      let (path, loop_start) = lasso_path(model, result)
      (path, "witness", Some(loop_start))
    }
    _ => ([], "none", None)
  }
  {
    holds,
    state_count: model.states.length(),
    satisfying_count,
    trace,
    trace_role,
    loop_start,
  }
}
