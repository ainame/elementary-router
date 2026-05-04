/// Describes a route-value decoding failure.
public enum RouteValueError: Error, Equatable, Sendable {
  /// A required value was not present.
  case missing(name: String)
  /// A raw string value could not be parsed as the requested type.
  case invalid(name: String, rawValue: String, expected: String)
}

/// Context passed to a generated `@RouteError` renderer.
public struct RouteErrorContext: Sendable {
  /// The decoding error thrown while rendering a matched route.
  public let error: RouteValueError
  /// The route context that produced the error.
  public let routeContext: RouteContext
}

/// Errors surfaced when the router cannot render the current location.
public enum RouterRenderError: Error, Equatable, Sendable {
  /// No route matched the current location and no not-found renderer was configured.
  case routeNotFound
  /// A matched route threw `RouteValueError` and no route-error renderer was configured.
  case routeRenderFailed(RouteValueError)
}
