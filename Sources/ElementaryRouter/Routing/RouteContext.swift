public struct RouteHandle: Hashable, Equatable, Sendable, Identifiable {
  public struct ID: Hashable, Equatable, Sendable {
    let rawValue: Int
  }

  public let id: ID
}

struct RouteMatch: Equatable, Sendable {
  let route: RouteHandle
  let path: String
  let params: RouteValues
}

public struct RouteContext: Sendable {
  public let route: RouteHandle
  public let path: String
  public let params: RouteValues
  public let query: RouteValues
  public let location: RouteLocation
  public let matchedRoutes: [RouteHandle]
}
