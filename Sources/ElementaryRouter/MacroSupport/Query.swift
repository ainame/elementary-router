/// Marks a route function parameter as coming from the URL query string.
///
/// Use `Query<Value>` in `@Route` and `@Layout` signatures when a value should be decoded from
/// `?name=value` pairs instead of the path pattern.
public struct Query<Value: RouteValue & Equatable>: Equatable, Sendable {
  /// The wrapped decoded value.
  public let value: Value

  /// Creates a query parameter marker for the given value.
  public init(_ value: Value) {
    self.value = value
  }
}

extension Query where Value == String {
  public init(stringLiteral value: String) {
    self.value = value
  }
}
