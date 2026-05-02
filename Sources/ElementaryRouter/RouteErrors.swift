public enum RouteTreeError: Error, Equatable, Sendable {
  case duplicateRoute(path: String)
  case duplicateParameter(path: String, name: String)
}

public enum RouteMatchError: Error, Equatable, Sendable {
  case unknownRoute
  case missingRequiredParameter(name: String)
}

public enum RouterRenderError: Error, Equatable, Sendable {
  case routeNotFound
  case routeRenderFailed(RouteValueError)
}
