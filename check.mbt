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
  satisfying : Array[Bool]
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
/// Whether a state satisfies the formula. Indices follow the input model's
/// state order; out-of-range indices return None.
pub fn Report::satisfies_at(self : Report, index : Int) -> Bool? {
  self.satisfying.get(index)
}

///|
/// Returns a defensive copy of the witness/counterexample available for the
/// top-level formula. Empty means no path is exposed. Finite paths are
/// shortest under their formula constraints; looping paths end with a repeated
/// state identified by `loop_start`.
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
  for edge in model.outgoing[state] {
    if set[edge.to] {
      return true
    }
  }
  false
}

///|
fn all_next(model : Model, set : Array[Bool], state : Int) -> Bool {
  for edge in model.outgoing[state] {
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
/// Least fixed point for F and U. Each newly satisfying state notifies its
/// predecessors once per incoming edge. `condition` is None for F.
fn least_fixpoint(
  model : Model,
  terminal : Array[Bool],
  condition : Array[Bool]?,
  existential : Bool,
) -> Array[Bool] {
  let result = terminal.copy()
  let queue : Array[Int] = []
  let pending = Array::makei(result.length(), i => model.outgoing[i].length())
  for i in 0..<result.length() {
    if result[i] {
      queue.push(i)
    }
  }
  let mut head = 0
  while head < queue.length() {
    let current = queue[head]
    head += 1
    for predecessor in model.incoming[current] {
      if result[predecessor] {
        continue
      }
      let allowed = match condition {
        Some(c) => c[predecessor]
        None => true
      }
      if existential {
        if allowed {
          result[predecessor] = true
          queue.push(predecessor)
        }
      } else {
        pending[predecessor] -= 1
        if allowed && pending[predecessor] == 0 {
          result[predecessor] = true
          queue.push(predecessor)
        }
      }
    }
  }
  result
}

///|
/// Greatest fixed point for G. Removing a state only revisits predecessors
/// whose path condition might now fail.
fn greatest_fixpoint(
  model : Model,
  condition : Array[Bool],
  existential : Bool,
) -> Array[Bool] {
  let result = condition.copy()
  let queue : Array[Int] = []
  if existential {
    let live = Array::make(result.length(), 0)
    for i in 0..<result.length() {
      if result[i] {
        for edge in model.outgoing[i] {
          if result[edge.to] {
            live[i] += 1
          }
        }
        if live[i] == 0 {
          queue.push(i)
        }
      }
    }
    let mut head = 0
    while head < queue.length() {
      let current = queue[head]
      head += 1
      if !result[current] {
        continue
      }
      result[current] = false
      for predecessor in model.incoming[current] {
        if result[predecessor] {
          live[predecessor] -= 1
          if live[predecessor] == 0 {
            queue.push(predecessor)
          }
        }
      }
    }
  } else {
    for i in 0..<result.length() {
      if !result[i] {
        queue.push(i)
      }
    }
    let mut head = 0
    while head < queue.length() {
      let current = queue[head]
      head += 1
      for predecessor in model.incoming[current] {
        if result[predecessor] {
          result[predecessor] = false
          queue.push(predecessor)
        }
      }
    }
  }
  result
}

///|
/// BFS returns a shortest path; edge declaration order breaks equal-length
/// ties. When `allowed` is supplied, only allowed states may be traversed
/// before reaching a target state.
fn shortest_path(
  model : Model,
  target : Array[Bool],
  allowed : Array[Bool]?,
) -> Array[TraceStep] {
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
    if allowed is Some(set) && !set[current] {
      continue
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
/// An EX witness or AX counterexample needs exactly one transition. Dead-end
/// states use the same implicit self-loop as the CTL evaluator.
fn one_step_path(model : Model, target : Array[Bool]) -> Array[TraceStep] {
  for edge in model.successors(model.initial) {
    if target[edge.to] {
      return [
        { state: model.states[model.initial].id, via: None, },
        { state: model.states[edge.to].id, via: Some(edge.action), },
      ]
    }
  }
  []
}

///|
/// Construct an ultimately periodic path that stays in `allowed`. For AF/AU
/// failures or EG successes, fixed-point semantics guarantees a successor in
/// that set. A dead-end state has a self-loop in the normalized graph.
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
/// Includes paths for top-level EX/AX/EF/AF/EG/AG/EU/AU when one path can
/// witness the result. Universal until failure may be a finite violation or
/// an infinite loop avoiding the goal.
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
    EX(inner) if holds => {
      let next = evaluate(model, inner)
      (one_step_path(model, next), "witness", None)
    }
    AX(inner) if !holds => {
      let next = evaluate(model, inner)
      (one_step_path(model, next.map(v => !v)), "counterexample", None)
    }
    AG(inner) if !holds => {
      let safe = evaluate(model, inner)
      (shortest_path(model, safe.map(v => !v), None), "counterexample", None)
    }
    EF(inner) if holds => {
      let goal = evaluate(model, inner)
      (shortest_path(model, goal, None), "witness", None)
    }
    AF(_) if !holds => {
      let (path, loop_start) = lasso_path(model, result.map(v => !v))
      (path, "counterexample", Some(loop_start))
    }
    EG(_) if holds => {
      let (path, loop_start) = lasso_path(model, result)
      (path, "witness", Some(loop_start))
    }
    EU(left, right) if holds => {
      let before = evaluate(model, left)
      let goal = evaluate(model, right)
      (shortest_path(model, goal, Some(before)), "witness", None)
    }
    AU(left, right) if !holds => {
      let before = evaluate(model, left)
      let goal = evaluate(model, right)
      let bad = result.map(v => !v)
      let violation = Array::makei(model.states.length(), i => {
        !before[i] && !goal[i]
      })
      let finite = shortest_path(model, violation, Some(bad))
      if finite.length() > 0 {
        (finite, "counterexample", None)
      } else {
        let (path, loop_start) = lasso_path(model, bad)
        (path, "counterexample", Some(loop_start))
      }
    }
    _ => ([], "none", None)
  }
  {
    holds,
    state_count: model.states.length(),
    satisfying_count,
    satisfying: result,
    trace,
    trace_role,
    loop_start,
  }
}
