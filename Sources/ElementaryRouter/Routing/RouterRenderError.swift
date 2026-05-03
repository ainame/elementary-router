public enum RouterRenderError: Error, Equatable, Sendable {
  case routeNotFound
  case routeRenderFailed(RouteValueError)
}
