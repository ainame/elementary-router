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
