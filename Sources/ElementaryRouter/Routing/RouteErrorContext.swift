public enum RouteValueError: Error, Equatable, Sendable {
  case missing(name: String)
  case invalid(name: String, rawValue: String, expected: String)
}

public struct RouteErrorContext: Sendable {
  public let error: RouteValueError
  public let routeContext: RouteContext
}

public enum RouterRenderError: Error, Equatable, Sendable {
  case routeNotFound
  case routeRenderFailed(RouteValueError)
}
