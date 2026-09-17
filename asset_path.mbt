///|
fn is_safe_asset_path(path : String) -> Bool {
  if path == "" || path.has_prefix("/") || path.contains("\\") {
    return false
  }
  let mut component = ""
  for character in path {
    if character == '/' {
      if !is_safe_path_component(component) {
        return false
      }
      component = ""
    } else {
      if character == ':' || character == '\u0000' {
        return false
      }
      component += character.to_string()
    }
  }
  is_safe_path_component(component)
}

///|
fn is_safe_path_component(component : String) -> Bool {
  component != "" && component != "." && component != ".."
}

///|
fn join_asset_path(root : String, relative_path : String) -> String {
  let separator = if root.contains("\\") { "\\" } else { "/" }
  let mut normalized_path = ""
  for character in relative_path {
    if character == '/' {
      normalized_path += separator
    } else {
      normalized_path += character.to_string()
    }
  }
  join_path(root, normalized_path)
}

///|
async fn collect_asset_files(root : String) -> Array[String] {
  let directories : Array[String] = [""]
  let files : Array[String] = []
  let mut directory_index = 0
  while directory_index < directories.length() {
    let relative_directory = directories[directory_index]
    let directory_path = if relative_directory == "" {
      root
    } else {
      join_asset_path(root, relative_directory)
    }
    let entries = @fs.readdir(directory_path, sort=true)
    for entry in entries {
      let relative_path = if relative_directory == "" {
        entry
      } else {
        relative_directory + "/" + entry
      }
      let full_path = join_asset_path(root, relative_path)
      match @fs.kind(full_path, follow_symlink=false) {
        @fs.FileKind::Directory => directories.push(relative_path)
        @fs.FileKind::Regular | @fs.FileKind::SymLink =>
          files.push(relative_path)
        _ => ()
      }
    }
    directory_index += 1
  }
  files
}

///|
fn contains_entry(entries : Array[String], expected : String) -> Bool {
  for entry in entries {
    if entry == expected {
      return true
    }
  }
  false
}

///|
fn join_path(root : String, name : String) -> String {
  if root.has_suffix("/") || root.has_suffix("\\") {
    root + name
  } else if root.contains("\\") {
    root + "\\" + name
  } else {
    root + "/" + name
  }
}
