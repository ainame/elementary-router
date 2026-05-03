struct RoutePattern: Equatable, Sendable {
  enum Segment: Equatable, Sendable {
    case literal(String)
    case parameter(String)
    case wildcard
  }

  let original: String
  let path: String
  let segments: [Segment]

  init(_ path: String) throws(RouteTreeError) {
    self.original = path
    self.path = RoutePattern.normalized(path)
    self.segments = try RoutePattern.parseSegments(self.path)
  }

  func match(_ path: String) -> RouteParameters? {
    match(path, allowPrefix: false)
  }

  func prefixMatch(_ path: String) -> RouteParameters? {
    match(path, allowPrefix: true)
  }

  private func match(_ path: String, allowPrefix: Bool) -> RouteParameters? {
    let pathSegments = RoutePattern.pathSegments(RoutePattern.normalized(path))
    var values = RouteParameters()
    var patternIndex = 0
    var pathIndex = 0

    while patternIndex < segments.count {
      let segment = segments[patternIndex]
      switch segment {
      case .literal(let value):
        guard pathIndex < pathSegments.count, pathSegments[pathIndex] == value else {
          return nil
        }
        patternIndex += 1
        pathIndex += 1
      case .parameter(let name):
        guard pathIndex < pathSegments.count else { return nil }
        values.append(name, URLCoding.decode(pathSegments[pathIndex], plusIsSpace: false))
        patternIndex += 1
        pathIndex += 1
      case .wildcard:
        let rest = pathSegments[pathIndex...].joined(separator: "/")
        values.append("*", URLCoding.decode(rest, plusIsSpace: false))
        return values
      }
    }

    return allowPrefix || pathIndex == pathSegments.count ? values : nil
  }

  func buildPath(params: RouteParameters) throws(RouteMatchError) -> String {
    if segments.isEmpty { return "/" }

    var result = ""
    for segment in segments {
      result += "/"
      switch segment {
      case .literal(let value):
        result += URLCoding.encode(value, spaceAsPlus: false)
      case .parameter(let name):
        guard let value = params.get(name) else {
          throw RouteMatchError.missingRequiredParameter(name: name)
        }
        result += URLCoding.encode(value, spaceAsPlus: false)
      case .wildcard:
        guard let value = params.get("*") else {
          throw RouteMatchError.missingRequiredParameter(name: "*")
        }
        result += value.split(separator: "/")
          .map { URLCoding.encode(String($0), spaceAsPlus: false) }
          .joined(separator: "/")
      }
    }
    return result
  }

  var specificity: Int {
    var score = 0
    for segment in segments {
      switch segment {
      case .literal: score += 100
      case .parameter: score += 10
      case .wildcard: score -= 1
      }
    }
    return score
  }

  var depth: Int {
    segments.count
  }

  private static func normalized(_ path: String) -> String {
    var normalized = RouteLocation.normalizedPath(path)
    while normalized.count > 1 && normalized.last == "/" {
      normalized.removeLast()
    }
    return normalized
  }

  private static func parseSegments(_ path: String) throws(RouteTreeError) -> [Segment] {
    var seenParams: [String] = []
    let rawSegments = pathSegments(path)
    var segments: [Segment] = []

    for rawSegment in rawSegments {
      if rawSegment == "*" {
        segments.append(.wildcard)
      } else if rawSegment.first == ":" {
        let name = String(rawSegment.dropFirst())
        if seenParams.contains(name) {
          throw RouteTreeError.duplicateParameter(path: path, name: name)
        }
        seenParams.append(name)
        segments.append(.parameter(name))
      } else {
        segments.append(.literal(URLCoding.decode(rawSegment, plusIsSpace: false)))
      }
    }

    return segments
  }

  private static func pathSegments(_ path: String) -> [String] {
    var segments: [String] = []
    var start = path.startIndex
    var index = path.startIndex

    while index < path.endIndex {
      if path[index] == "/" {
        if start < index {
          segments.append(String(path[start..<index]))
        }
        start = path.index(after: index)
      }
      index = path.index(after: index)
    }

    if start < path.endIndex {
      segments.append(String(path[start..<path.endIndex]))
    }

    return segments
  }
}
