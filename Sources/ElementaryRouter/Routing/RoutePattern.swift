struct RoutePattern: Equatable, Sendable {
  enum Segment: Equatable, Sendable {
    /// A static segment, stored percent-decoded.
    case literal(String)
    case parameter(String)
    case wildcard
  }

  /// A segment with parameter names erased.
  ///
  /// Two patterns with the same shape match exactly the same set of URLs, so the router cannot
  /// choose between them.
  enum ShapeSegment: Equatable, Sendable {
    case literal(String)
    case parameter
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

  var shape: [ShapeSegment] {
    segments.map { segment -> ShapeSegment in
      switch segment {
      case .literal(let value): return .literal(value)
      case .parameter: return .parameter
      case .wildcard: return .wildcard
      }
    }
  }

  func match(_ path: String) -> RouteValues? {
    match(path, allowPrefix: false)
  }

  func prefixMatch(_ path: String) -> RouteValues? {
    match(path, allowPrefix: true)
  }

  private func match(_ path: String, allowPrefix: Bool) -> RouteValues? {
    let pathSegments = RoutePattern.pathSegments(RoutePattern.normalized(path))
    var values = RouteValues()
    var patternIndex = 0
    var pathIndex = 0

    while patternIndex < segments.count {
      let segment = segments[patternIndex]
      switch segment {
      case .literal(let value):
        guard pathIndex < pathSegments.count,
          URLCoding.decode(pathSegments[pathIndex], plusIsSpace: false) == value
        else {
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

  func buildPath(params: RouteValues) throws(RouteMatchError) -> String {
    var result = ""
    for segment in segments {
      switch segment {
      case .literal(let value):
        result += "/" + URLCoding.encode(value, spaceAsPlus: false)
      case .parameter(let name):
        // An empty segment would collapse away and the URL would no longer match this route.
        guard let value = params.get(name), !value.isEmpty else {
          throw RouteMatchError.missingRequiredParameter(name: name)
        }
        result += "/" + URLCoding.encode(value, spaceAsPlus: false)
      case .wildcard:
        guard let value = params.get("*") else {
          throw RouteMatchError.missingRequiredParameter(name: "*")
        }
        for part in value.split(separator: "/") {
          result += "/" + URLCoding.encode(String(part), spaceAsPlus: false)
        }
      }
    }
    return result.isEmpty ? "/" : result
  }

  /// Orders two patterns for matching.
  ///
  /// Patterns are compared segment by segment from left to right. At the first position where
  /// they differ, a static segment wins over a parameter, and a parameter wins over a wildcard.
  /// A pattern that ends where the other continues with a wildcard wins, so `/files` is tried
  /// before `/files/*`.
  ///
  /// Returns a negative value when `self` is tried first, a positive value when `other` is tried
  /// first, and zero when the segment kinds are identical.
  func compareRank(to other: RoutePattern) -> Int {
    var index = 0
    while index < segments.count || index < other.segments.count {
      let lhs = RoutePattern.rank(segments, at: index)
      let rhs = RoutePattern.rank(other.segments, at: index)
      if lhs != rhs {
        return lhs > rhs ? -1 : 1
      }
      index += 1
    }
    return 0
  }

  var depth: Int {
    segments.count
  }

  private static func rank(_ segments: [Segment], at index: Int) -> Int {
    guard index < segments.count else { return 4 }
    switch segments[index] {
    case .literal: return 3
    case .parameter: return 2
    case .wildcard: return 1
    }
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

    for (index, rawSegment) in rawSegments.enumerated() {
      if rawSegment == "*" {
        guard index == rawSegments.count - 1 else {
          throw RouteTreeError.invalidWildcard(path: path)
        }
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
