///|
pub suberror ManifestParseError {
  InvalidJson(String)
  DuplicateJsonKey(String)
  InvalidField(String)
} derive(Debug)

///|
/// Parse a manifest while rejecting duplicate keys and unsupported fields.
/// Use this entry point when a library consumer reads a manifest from JSON.
pub fn parse_manifest_json(text : String) -> Manifest raise ManifestParseError {
  match first_duplicate_json_key(text) {
    Some(key) => raise ManifestParseError::DuplicateJsonKey(key)
    None => ()
  }
  let json = @json.parse(text) catch {
    error => raise ManifestParseError::InvalidJson("\{error}")
  }
  match first_manifest_field_error(json) {
    Some(message) => raise ManifestParseError::InvalidField(message)
    None => ()
  }
  @json.from_json(json) catch {
    error => raise ManifestParseError::InvalidJson("\{error}")
  }
}

///|
/// JSON objects normally decode into maps, which erase repeated member names.
/// Scan the original text first so ambiguous requirements cannot pass silently.
fn first_duplicate_json_key(text : String) -> String? {
  let input = text[:]
  let object_keys : Array[Map[String, Bool]] = []
  let mut in_string = false
  let mut escaped = false
  let mut quote_start = 0
  for index in 0..<input.length() {
    let code = input.unsafe_get(index)
    if in_string {
      if escaped {
        escaped = false
      } else if code == 92 {
        escaped = true
      } else if code == 34 {
        in_string = false
        let mut colon = index + 1
        while colon < input.length() {
          let whitespace = input.unsafe_get(colon)
          if whitespace == 32 ||
            whitespace == 9 ||
            whitespace == 10 ||
            whitespace == 13 {
            colon += 1
          } else {
            break
          }
        }
        if colon < input.length() &&
          input.unsafe_get(colon) == 58 &&
          object_keys.length() > 0 {
          let key_literal = input
            .view(start_offset=quote_start, end_offset=index + 1)
            .to_owned()
          let parsed_key = @json.parse(key_literal) catch { _ => Json::null() }
          match parsed_key {
            String(key) => {
              let last = object_keys.length() - 1
              let keys = object_keys[last]
              if keys.contains(key) {
                return Some(key)
              }
              keys.set(key, true)
              object_keys[last] = keys
            }
            _ => ()
          }
        }
      }
    } else if code == 34 {
      in_string = true
      escaped = false
      quote_start = index
    } else if code == 123 {
      object_keys.push(Map([]))
    } else if code == 125 {
      ignore(object_keys.pop())
    }
  }
  None
}

///|
/// Reject misspelled keys and fractional dimensions or byte limits instead
/// of silently ignoring or truncating a handoff requirement.
fn first_manifest_field_error(json : Json) -> String? {
  match json {
    Object(root) =>
      for key, value in root {
        if key != "assets" && key != "max_total_bytes" {
          return Some(
            unknown_field_message(key, key, ["assets", "max_total_bytes"]),
          )
        }
        if key == "max_total_bytes" {
          match value {
            Number(number, ..) if number.floor() != number =>
              return Some("max_total_bytes 必须是整数")
            Number(number, ..) if number <= 0 =>
              return Some("max_total_bytes 必须为正整数")
            _ => ()
          }
        } else {
          match value {
            Array(assets) =>
              for index in 0..<assets.length() {
                match assets[index] {
                  Object(fields) =>
                    for field, field_value in fields {
                      if field != "file" &&
                        field != "label" &&
                        field != "width" &&
                        field != "height" &&
                        field != "max_bytes" &&
                        field != "min_bytes" &&
                        field != "expected_sha256" &&
                        field != "aspect" &&
                        field != "format" {
                        return Some(
                          unknown_field_message(
                            "assets[\{index}].\{field}",
                            field,
                            asset_field_names(),
                          ),
                        )
                      }
                      if field == "expected_sha256" {
                        match field_value {
                          String(expected) => {
                            if expected.length() != 64 {
                              return Some(
                                "assets[\{index}].expected_sha256 必须是 64 位十六进制字符串",
                              )
                            }
                            for character in expected {
                              if !is_hex_character(character) {
                                return Some(
                                  "assets[\{index}].expected_sha256 必须是 64 位十六进制字符串",
                                )
                              }
                            }
                          }
                          _ => ()
                        }
                      }
                      if field == "aspect" {
                        match field_value {
                          String(aspect) =>
                            if parse_aspect(aspect) is None {
                              return Some(
                                "assets[\{index}].aspect 必须是 W:H 形式的正整数比例",
                              )
                            }
                          _ => ()
                        }
                      }
                      if field == "min_bytes" {
                        match field_value {
                          Number(number, ..) if number.floor() != number =>
                            return Some(
                              "assets[\{index}].min_bytes 必须是整数",
                            )
                          Number(number, ..) if number <= 0 =>
                            return Some(
                              "assets[\{index}].min_bytes 必须为正整数",
                            )
                          _ => ()
                        }
                      }
                      if field == "format" {
                        match field_value {
                          String(format) =>
                            if canonical_format(format) is None {
                              return Some(
                                "assets[\{index}].format 必须是受支持的格式名（如 png、jpeg、webp、svg）",
                              )
                            }
                          _ => ()
                        }
                      }
                      if field == "width" ||
                        field == "height" ||
                        field == "max_bytes" {
                        match field_value {
                          Number(number, ..) if number.floor() != number =>
                            return Some(
                              "assets[\{index}].\{field} 必须是整数",
                            )
                          _ => ()
                        }
                      }
                    }
                  _ => ()
                }
              }
            _ => ()
          }
        }
      }
    _ => ()
  }
  None
}

///|
fn is_hex_character(character : Char) -> Bool {
  (character >= '0' && character <= '9') ||
  (character >= 'a' && character <= 'f') ||
  (character >= 'A' && character <= 'F')
}

///|
fn asset_field_names() -> Array[String] {
  [
    "file", "label", "width", "height", "max_bytes", "min_bytes", "expected_sha256",
    "aspect", "format",
  ]
}

///|
fn unknown_field_message(
  path : String,
  field : String,
  candidates : Array[String],
) -> String {
  match closest_match(field, candidates) {
    Some(suggestion) =>
      "未知字段 \{path}，你是不是想写 \{suggestion}？"
    None => "未知字段 \{path}"
  }
}
