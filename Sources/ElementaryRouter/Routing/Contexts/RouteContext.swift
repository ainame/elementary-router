public struct RouteContext: Sendable {
  public let params: RouteParameters
  public let query: RouteParameters
  public let location: RouteLocation
  public let match: RouteMatch
  public let matches: [RouteMatch]

  public init(
    params: RouteParameters,
    query: RouteParameters,
    location: RouteLocation,
    match: RouteMatch,
    matches: [RouteMatch]
  ) {
    self.params = params
    self.query = query
    self.location = location
    self.match = match
    self.matches = matches
  }
}
