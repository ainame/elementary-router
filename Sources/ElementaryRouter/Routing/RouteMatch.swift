public struct RouteMatch: Equatable, Sendable {
  public let route: RouteHandle
  public let path: String
  public let params: RouteParameters

  public init(route: RouteHandle, path: String, params: RouteParameters) {
    self.route = route
    self.path = path
    self.params = params
  }
}
