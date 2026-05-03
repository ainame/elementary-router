public struct RouteHandle: Hashable, Equatable, Sendable, Identifiable {
  public struct ID: Hashable, Equatable, Sendable {
    let rawValue: Int
  }

  public let id: ID
}
