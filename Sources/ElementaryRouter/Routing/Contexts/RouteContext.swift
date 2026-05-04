public struct RouteContext: Sendable {
  public let route: RouteHandle
  public let path: String
  public let params: RouteParameters
  public let query: RouteParameters
  public let location: RouteLocation
  public let matchedRoutes: [RouteHandle]
}
