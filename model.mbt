///|
/// One state in an explicitly enumerated finite transition system.
pub(all) struct State {
  id : String
  labels : Array[String]
} derive(Debug)

///|
pub extend State with Debug::{to_repr}

///|
/// A directed transition. `action` is used in counterexample traces.
pub(all) struct Edge {
  from : Int
  to : Int
  action : String
} derive(Debug)

///|
pub extend Edge with Debug::{to_repr}

///|
pub(all) enum ModelError {
  EmptyStates
  InvalidInitial(Int)
  DuplicateState(String)
  InvalidEdge(Int, Int)
} derive(Debug)

///|
pub extend ModelError with Debug::{to_repr}

///|
/// A complete, finite transition system. Dead-end states have an implicit
/// self-loop when interpreting CTL, following the usual total Kripke semantics.
pub struct Model {
  states : Array[State]
  outgoing : Array[Array[Edge]]
  incoming : Array[Array[Int]]
  initial : Int
}

///|
pub fn Model::new(
  states : Array[State],
  edges : Array[Edge],
  initial~ : Int,
) -> Result[Model, ModelError] {
  let count = states.length()
  if count == 0 {
    return Err(EmptyStates)
  }
  if initial < 0 || initial >= count {
    return Err(InvalidInitial(initial))
  }
  let ids : Map[String, Bool] = Map([])
  for state in states {
    if ids.contains(state.id) {
      return Err(DuplicateState(state.id))
    }
    ids[state.id] = true
  }
  let outgoing = Array::makei(count, _ => Array())
  for edge in edges {
    if edge.from < 0 || edge.from >= count || edge.to < 0 || edge.to >= count {
      return Err(InvalidEdge(edge.from, edge.to))
    }
    outgoing[edge.from].push(edge)
  }
  for i in 0..<count {
    if outgoing[i].is_empty() {
      outgoing[i].push({ from: i, to: i, action: "<stutter>", })
    }
  }
  let incoming = Array::makei(count, _ => Array())
  for i in 0..<count {
    for edge in outgoing[i] {
      incoming[edge.to].push(i)
    }
  }
  let owned_states = states.map(s => State::{
    id: s.id,
    labels: s.labels.copy(),
  })
  Ok({ states: owned_states, outgoing, incoming, initial, })
}

///|
pub fn Model::state_count(self : Model) -> Int {
  self.states.length()
}

///|
pub fn Model::initial(self : Model) -> Int {
  self.initial
}

///|
pub fn Model::state_id(self : Model, index : Int) -> String? {
  self.states.get(index).map(s => s.id)
}

///|
pub fn Model::has_label(self : Model, index : Int, label : String) -> Bool {
  match self.states.get(index) {
    Some(state) => state.labels.contains(label)
    None => false
  }
}

///|
pub fn Model::successors(self : Model, index : Int) -> Array[Edge] {
  match self.outgoing.get(index) {
    Some(edges) => edges.copy()
    _ => []
  }
}
