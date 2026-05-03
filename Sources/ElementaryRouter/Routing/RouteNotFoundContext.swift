public struct RouteNotFoundContext: Sendable {
  public let location: RouteLocation
  public let query: RouteParameters

  public init(location: RouteLocation, query: RouteParameters) {
    self.location = location
    self.query = query
  }
}
