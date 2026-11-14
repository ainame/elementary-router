/// The document path prefix that a path-mode app is served under, such as `/SpeedMath`.
///
/// Route locations are relative to the base path: the document path `/SpeedMath/users/42` is the
/// route path `/users/42`, and `/SpeedMath` or `/SpeedMath/` is `/`. A document path outside the
/// base path, such as `/other` or `/SpeedMathOld`, has no route location.
///
/// The prefix is compared byte for byte with the percent-encoded document path, so it is
/// case-sensitive and must be written as the browser reports it in `location.pathname`.
struct BasePath: Equatable, Sendable {
  /// `""` for no base path; otherwise one leading slash and no trailing slash, such as `/a/b`.
  let value: String

  /// Normalizes `rawValue`: leading and trailing slashes are optional, and `""` or `/` mean no
  /// base path.
  init(_ rawValue: String) {
    var trimmed = Substring(rawValue)
    while trimmed.utf8.first == UInt8(ascii: "/") {
      trimmed = trimmed.dropFirst()
    }
    while trimmed.utf8.last == UInt8(ascii: "/") {
      trimmed = trimmed.dropLast()
    }
    value = trimmed.isEmpty ? "" : "/" + String(trimmed)
  }

  static var none: BasePath {
    BasePath("")
  }

  /// The route location of a document location, or `nil` when it is outside the base path.
  func routeLocation(in document: RouteLocation) -> RouteLocation? {
    guard !value.isEmpty else { return document }

    let path = document.path.utf8
    guard path.starts(with: value.utf8) else { return nil }
    let rest = path.dropFirst(value.utf8.count)
    guard rest.isEmpty || rest.first == UInt8(ascii: "/") else { return nil }

    return RouteLocation(
      path: String(decoding: rest, as: UTF8.self),
      queryString: document.queryString,
      hash: document.hash,
      state: document.state
    )
  }

  /// The document location of a route location; the route root `/` becomes `/base/`.
  func documentLocation(for location: RouteLocation) -> RouteLocation {
    guard !value.isEmpty else { return location }

    var document = location
    document.path = value + location.path
    return document
  }
}
