/// A browser location split into path, query string, hash, and optional history state.
public struct RouteLocation: Equatable, Sendable {
  /// The normalized route path. Empty paths are normalized to `/`.
  public var path: String
  /// The raw query string without a leading `?`.
  public var queryString: String
  /// The raw hash fragment without a leading `#`.
  public var hash: String
  /// The associated browser history state, if any.
  public var state: String?

  /// Creates a location from already separated URL parts.
  public init(path: String = "/", queryString: String = "", hash: String = "", state: String? = nil) {
    self.path = RouteLocation.normalizedPath(path)
    self.queryString = RouteLocation.trimmedQuery(queryString)
    self.hash = RouteLocation.trimmedHash(hash)
    self.state = state
  }

  /// Creates a location by splitting a single URL-like string.
  public init(url: String, state: String? = nil) {
    let parts = RouteLocation.split(url)
    self.init(path: parts.path, queryString: parts.query, hash: parts.hash, state: state)
  }

  /// Returns the string form used for browser navigation and links.
  public var href: String {
    var result = path
    if !queryString.isEmpty {
      result += "?" + queryString
    }
    if !hash.isEmpty {
      result += "#" + hash
    }
    return result
  }

  static func normalizedPath(_ path: String) -> String {
    if path.isEmpty { return "/" }
    return path.first == "/" ? path : "/" + path
  }

  static func trimmedQuery(_ query: String) -> String {
    query.first == "?" ? String(query.dropFirst()) : query
  }

  static func trimmedHash(_ hash: String) -> String {
    hash.first == "#" ? String(hash.dropFirst()) : hash
  }

  static func split(_ url: String) -> (path: String, query: String, hash: String) {
    var pathEnd = url.endIndex
    var queryStart: String.Index?
    var hashStart: String.Index?

    var index = url.startIndex
    while index < url.endIndex {
      let character = url[index]
      if character == "?" && queryStart == nil && hashStart == nil {
        queryStart = index
        pathEnd = index
      } else if character == "#" && hashStart == nil {
        hashStart = index
        if queryStart == nil {
          pathEnd = index
        }
        break
      }
      index = url.index(after: index)
    }

    let path = String(url[..<pathEnd])

    let query: String
    if let queryStart {
      let start = url.index(after: queryStart)
      let end = hashStart ?? url.endIndex
      query = String(url[start..<end])
    } else {
      query = ""
    }

    let hash: String
    if let hashStart {
      hash = String(url[url.index(after: hashStart)..<url.endIndex])
    } else {
      hash = ""
    }

    return (path, query, hash)
  }
}
