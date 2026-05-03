public enum RouteTreeError: Error, Equatable, Sendable {
  case duplicateRoute(path: String)
  case duplicateParameter(path: String, name: String)
}
