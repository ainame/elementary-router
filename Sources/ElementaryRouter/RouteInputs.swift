public struct Wildcard: Equatable, Sendable {
  public let value: String

  public init(_ value: String) {
    self.value = value
  }
}

public struct Query<Value: RouteValue>: Equatable, Sendable where Value: Equatable & Sendable {
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
