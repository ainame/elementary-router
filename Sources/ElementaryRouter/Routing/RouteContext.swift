/// Identifies a route registered in a route tree.
///
/// Handles are generated during route registration and are used for navigation, active-route
/// checks, and URL building. They do not encode a path directly; the route tree resolves them.
public struct RouteHandle: Hashable, Equatable, Sendable, Identifiable {
  /// Opaque stable identifier for a registered route.
  public struct ID: Hashable, Equatable, Sendable {
    let rawValue: Int
  }

  /// The opaque identifier of this route handle.
  public let id: ID
}

struct RouteMatch: Equatable, Sendable {
  let route: RouteHandle
  let path: String
  let params: RouteValues
}

/// Runtime context passed to matched route and layout renderers.
///
/// A `RouteContext` contains the matched route handle, decoded path and query values, the current
/// browser location, and the parent-to-leaf route stack for the current match.
public struct RouteContext: Sendable {
  /// The route currently being rendered.
  public let route: RouteHandle
  /// The declared route path for the current matched record.
  public let path: String
  /// Decoded path parameter values for the current matched record.
  public let params: RouteValues
  /// Parsed query parameter values for the current location.
  public let query: RouteValues
  /// The current browser location being rendered.
  public let location: RouteLocation
  /// The full parent-to-leaf route stack for the current location.
  public let matchedRoutes: [RouteHandle]
}
