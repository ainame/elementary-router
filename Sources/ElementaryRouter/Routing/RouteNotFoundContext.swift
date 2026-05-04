/// Context passed to a generated `@NotFound` renderer.
public struct RouteNotFoundContext: Sendable {
  /// The current browser location that failed to match any route.
  public let location: RouteLocation
  /// Parsed query parameter values for the unmatched location.
  public let query: RouteValues

  /// Creates a not-found rendering context.
  public init(location: RouteLocation, query: RouteValues) {
    self.location = location
    self.query = query
  }
}
