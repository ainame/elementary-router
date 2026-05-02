public struct RouteLocation: Equatable, Sendable {
  public var path: String
  public var queryString: String
  public var hash: String
  public var state: String?

  public init(path: String = "/", queryString: String = "", hash: String = "", state: String? = nil)
  {
    self.path = RouteLocation.normalizedPath(path)
    self.queryString = RouteLocation.trimmedQuery(queryString)
    self.hash = RouteLocation.trimmedHash(hash)
    self.state = state
  }

  public init(url: String, state: String? = nil) {
    let parts = RouteLocation.split(url)
    self.init(path: parts.path, queryString: parts.query, hash: parts.hash, state: state)
  }

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
