/// Marks a route function parameter as receiving a wildcard path segment.
///
/// Use `Wildcard` with a route path that contains `*` to receive the matched remainder as a
/// single string value.
public struct Wildcard: Equatable, Sendable {
  /// The matched wildcard value.
  public let value: String

  /// Creates a wildcard value wrapper.
  public init(_ value: String) {
    self.value = value
  }
}
