public struct RouteHandle: Hashable, Equatable, Sendable, Identifiable {
  public struct ID: Hashable, Equatable, Sendable {
    let rawValue: Int
  }

  public let id: ID
}

public struct Query<Value: RouteValue & Equatable>: Equatable, Sendable {
  public let value: Value

  public init(_ value: Value) {
    self.value = value
  }
}

extension Query where Value == String {
  public init(stringLiteral value: String) {
    self.value = value
  }
}

public struct Wildcard: Equatable, Sendable {
  public let value: String

  public init(_ value: String) {
    self.value = value
  }
}

struct RouteMatch: Equatable, Sendable {
  let route: RouteHandle
  let path: String
  let params: RouteParameters
}

public struct RouteContext: Sendable {
  public let route: RouteHandle
  public let path: String
  public let params: RouteParameters
  public let query: RouteParameters
  public let location: RouteLocation
  public let matchedRoutes: [RouteHandle]
}
