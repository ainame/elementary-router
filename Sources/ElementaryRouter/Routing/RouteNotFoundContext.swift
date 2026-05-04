public struct RouteNotFoundContext: Sendable {
  public let location: RouteLocation
  public let query: RouteValues

  public init(location: RouteLocation, query: RouteValues) {
    self.location = location
    self.query = query
  }
}
