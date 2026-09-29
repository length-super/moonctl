///|
pub(all) suberror ModelJsonError {
  InvalidJson
  MissingField(String)
  WrongType(String)
  InvalidGraph(ModelError)
} derive(Debug)

///|
pub extend ModelJsonError with Debug::{to_repr}

///|
fn field(value : Json, key : String) -> Json raise ModelJsonError {
  match value {
    Object(map) =>
      match map.get(key) {
        Some(item) => item
        None => raise MissingField(key)
      }
    _ => raise WrongType("object")
  }
}

///|
fn string_field(value : Json, key : String) -> String raise ModelJsonError {
  match field(value, key) {
    String(s) => s
    _ => raise WrongType(key)
  }
}

///|
fn int_field(value : Json, key : String) -> Int raise ModelJsonError {
  match field(value, key) {
    Number(n, ..) => {
      let int = n.to_int()
      if n != int.to_double() {
        raise WrongType(key)
      }
      int
    }
    _ => raise WrongType(key)
  }
}

///|
fn array_field(value : Json, key : String) -> Array[Json] raise ModelJsonError {
  match field(value, key) {
    Array(items) => items
    _ => raise WrongType(key)
  }
}

///|
fn string_array_field(
  value : Json,
  key : String,
) -> Array[String] raise ModelJsonError {
  let result : Array[String] = []
  for item in array_field(value, key) {
    match item {
      String(s) => result.push(s)
      _ => raise WrongType(key)
    }
  }
  result
}

///|
/// Parse an explicit finite graph from JSON. The input is validated before
/// any temporal formula is checked.
pub fn load_model_json(source : String) -> Model raise ModelJsonError {
  let value = @json.parse(source) catch { _ => raise InvalidJson }
  let states : Array[State] = []
  let edges : Array[Edge] = []
  for raw in array_field(value, "states") {
    states.push({
      id: string_field(raw, "id"),
      labels: string_array_field(raw, "labels"),
    })
  }
  for raw in array_field(value, "edges") {
    edges.push({
      from: int_field(raw, "from"),
      to: int_field(raw, "to"),
      action: string_field(raw, "action"),
    })
  }
  let initial = int_field(value, "initial")
  match Model::new(states, edges, initial~) {
    Ok(model) => model
    Err(error) => raise InvalidGraph(error)
  }
}
