///|
/// A transition identified by state IDs instead of numeric indices.
pub(all) struct NamedEdge {
  from : String
  to : String
  action : String
} derive(Debug)

///|
pub extend NamedEdge with Debug::{to_repr}

///|
pub(all) enum NamedModelError {
  DuplicateName(String)
  UnknownState(String)
  InvalidModel(ModelError)
} derive(Debug)

///|
pub extend NamedModelError with Debug::{to_repr}

///|
/// Build a finite graph using stable state IDs. Every named transition must
/// refer to a declared state. A terminal state receives a stutter self-loop.
pub fn Model::from_named(
  states : Array[State],
  edges : Array[NamedEdge],
  initial : String,
) -> Result[Model, NamedModelError] {
  if states.is_empty() {
    return Err(InvalidModel(EmptyStates))
  }
  let indices : Map[String, Int] = Map([])
  for i in 0..<states.length() {
    let id = states[i].id
    if indices.contains(id) {
      return Err(DuplicateName(id))
    }
    indices[id] = i
  }
  let initial_index = match indices.get(initial) {
    Some(index) => index
    None => return Err(UnknownState(initial))
  }
  let indexed : Array[Edge] = []
  for edge in edges {
    let from = match indices.get(edge.from) {
      Some(index) => index
      None => return Err(UnknownState(edge.from))
    }
    let to = match indices.get(edge.to) {
      Some(index) => index
      None => return Err(UnknownState(edge.to))
    }
    indexed.push({ from, to, action: edge.action, })
  }
  match Model::new(states, indexed, initial=initial_index) {
    Ok(model) => Ok(model)
    Err(error) => Err(InvalidModel(error))
  }
}
