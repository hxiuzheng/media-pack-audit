///|
/// Small string-distance helpers used to turn "unknown field" manifest errors
/// into "did you mean X?" suggestions. Kept dependency-free so it can be unit
/// tested without touching the filesystem.

///|
/// Return the candidate closest to `value` by Levenshtein edit distance, or
/// `None` when every candidate is too far away to be a plausible typo.
pub fn closest_match(value : String, candidates : Array[String]) -> String? {
  let mut best : String? = None
  let mut best_distance = 0
  let mut first = true
  for candidate in candidates {
    let distance = levenshtein(value, candidate)
    if first || distance < best_distance {
      best = Some(candidate)
      best_distance = distance
      first = false
    }
  }
  match best {
    Some(name) =>
      if best_distance <= value.length() / 2 + 1 {
        Some(name)
      } else {
        None
      }
    None => None
  }
}

///|
/// Levenshtein edit distance between two strings using a rolling two-row DP.
fn levenshtein(a : String, b : String) -> Int {
  let a_chars = a.to_array()
  let b_chars = b.to_array()
  let a_length = a_chars.length()
  let b_length = b_chars.length()
  let mut previous : Array[Int] = []
  for column in 0..<=b_length {
    previous.push(column)
  }
  for row in 1..<=a_length {
    let current : Array[Int] = [row]
    for column in 1..<=b_length {
      let substitution_cost = if a_chars[row - 1] == b_chars[column - 1] {
        0
      } else {
        1
      }
      let insertion = current[column - 1] + 1
      let deletion = previous[column] + 1
      let substitution = previous[column - 1] + substitution_cost
      current.push(min3(insertion, deletion, substitution))
    }
    previous = current
  }
  previous[b_length]
}

///|
fn min3(first : Int, second : Int, third : Int) -> Int {
  if first <= second && first <= third {
    first
  } else if second <= third {
    second
  } else {
    third
  }
}

///|
test "computes Levenshtein edit distance" {
  assert_true(levenshtein("kitten", "sitting") == 3)
  assert_true(levenshtein("max_byts", "max_bytes") == 1)
  assert_true(levenshtein("", "abc") == 3)
  assert_true(levenshtein("same", "same") == 0)
}

///|
test "suggests the closest candidate only when it is close enough" {
  assert_true(
    closest_match("max_byts", ["file", "max_bytes", "width"]) ==
    Some("max_bytes"),
  )
  assert_true(closest_match("verison", ["assets", "max_total_bytes"]) is None)
  assert_true(closest_match("hieght", ["height", "width"]) == Some("height"))
}
