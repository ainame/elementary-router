public struct RouteID: Hashable, Equatable, Sendable {
  let rawValue: Int
}

public struct RouteHandle: Hashable, Equatable, Sendable, Identifiable {
  public let id: RouteID
}

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

public struct RouteNotFoundContext: Sendable {
  public let location: RouteLocation
  public let query: RouteParameters

  public init(location: RouteLocation, query: RouteParameters) {
    self.location = location
    self.query = query
  }
}

public struct RouteErrorContext: Sendable {
  public let error: RouteValueError
  public let routeContext: RouteContext

  public init(error: RouteValueError, routeContext: RouteContext) {
    self.error = error
    self.routeContext = routeContext
  }
}

enum RouteRenderResolution: Sendable {
  case matched(RouteContext)
  case notFound(RouteNotFoundContext)
  case error(RouteErrorContext)
}
