public enum RouteMatchError: Error, Equatable, Sendable {
  case unknownRoute
  case missingRequiredParameter(name: String)
}
