public enum RouteValueError: Error, Equatable, Sendable {
  case missing(name: String)
  case invalid(name: String, rawValue: String, expected: String)
}
