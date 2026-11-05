/// The identity shared by every route registered through one `RouteBuilder`.
///
/// Equality is object identity. Every handle retains its registration, so the identity cannot be
/// reused by another builder while any handle or tree from this builder is still alive.
final class RouteRegistration: Hashable, Sendable {
  init() {}

  static func == (lhs: RouteRegistration, rhs: RouteRegistration) -> Bool {
    lhs === rhs
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}

/// The identity of one compiled route tree, compared by object identity.
final class RouteTreeIdentity: Sendable {
  init() {}
}

/// Identifies a route registered in a route tree.
///
/// Handles are generated during route registration and are used for navigation, active-route
/// checks, and URL building. They do not encode a path directly; the route tree resolves them.
/// A handle belongs to the builder that registered it: handles from unrelated route trees, or
/// from separate `routes()` calls of the same `@Routes` type, never compare equal.
public struct RouteHandle: Hashable, Equatable, Sendable, Identifiable {
  /// Opaque stable identifier for a registered route.
  public struct ID: Hashable, Equatable, Sendable {
    let registration: RouteRegistration
    let index: Int
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
/// browser location, and the parent-to-leaf route stack for the current match. Every record of a
/// match has its own context: a layout's `route`, `path`, and `params` describe the layout, not
/// the leaf route below it.
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
