///|
/// A generated transition. Returning the same state ID with different labels
/// is an error, because atomic propositions must be stable for each state.
pub(all) struct Transition {
  to : State
  action : String
} derive(Debug)

///|
pub extend Transition with Debug::{to_repr}

///|
pub(all) enum ExploreLimit {
  StateBudgetReached
  EdgeBudgetReached
} derive(Debug)

///|
pub extend ExploreLimit with Debug::{to_repr}

///|
pub(all) enum ExploreError {
  InvalidBudget(Int, Int)
  ConflictingState(String)
  InvalidExploredGraph(ModelError)
} derive(Debug)

///|
pub extend ExploreError with Debug::{to_repr}

///|
/// `Incomplete` deliberately contains no Model. A partial graph cannot be
/// passed to `check` and mistaken for a proof about the whole system.
pub enum Exploration {
  Complete(Model)
  Incomplete(ExploreLimit, Int, Int)
}

///|
fn same_labels(left : Array[String], right : Array[String]) -> Bool {
  for label in left {
    if !right.contains(label) {
      return false
    }
  }
  for label in right {
    if !left.contains(label) {
      return false
    }
  }
  true
}

///|
/// Explore reachable states in breadth-first order. Limits include the
/// initial state and explicit transitions; synthesized stutter edges do not
/// consume the edge budget. Exactly reaching a limit can still be complete.
/// The callback receives a defensive copy of each discovered state.
pub fn explore(
  initial : State,
  next : (State) -> Array[Transition],
  max_states~ : Int,
  max_edges~ : Int,
) -> Result[Exploration, ExploreError] {
  if max_states < 1 || max_edges < 0 {
    return Err(InvalidBudget(max_states, max_edges))
  }
  let states : Array[State] = [
    { id: initial.id, labels: initial.labels.copy(), },
  ]
  let edges : Array[Edge] = []
  let indices : Map[String, Int] = Map([])
  indices[initial.id] = 0
  let mut head = 0
  while head < states.length() {
    let from = head
    let current = states[from]
    let transitions = next({ id: current.id, labels: current.labels.copy(), })
    for transition in transitions {
      if edges.length() == max_edges {
        return Ok(
          Incomplete(EdgeBudgetReached, states.length(), edges.length()),
        )
      }
      let to = match indices.get(transition.to.id) {
        Some(index) => {
          if !same_labels(states[index].labels, transition.to.labels) {
            return Err(ConflictingState(transition.to.id))
          }
          index
        }
        None => {
          if states.length() == max_states {
            return Ok(
              Incomplete(StateBudgetReached, states.length(), edges.length()),
            )
          }
          let index = states.length()
          states.push({
            id: transition.to.id,
            labels: transition.to.labels.copy(),
          })
          indices[transition.to.id] = index
          index
        }
      }
      edges.push({ from, to, action: transition.action, })
    }
    head += 1
  }
  match Model::new(states, edges, initial=0) {
    Ok(model) => Ok(Complete(model))
    Err(error) => Err(InvalidExploredGraph(error))
  }
}
