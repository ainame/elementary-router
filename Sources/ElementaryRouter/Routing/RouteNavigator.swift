import ElementaryUI

/// The router of a host route set, for views that only know its route content type.
///
/// A mounted feature, such as `ShopRoutes<Root>`, renders views that are generic over the host's
/// `Root` and cannot name the host's `Router` or `HashRouter`. Each router owns one navigator,
/// `router.navigator`; the host's generated `Provider` installs it, and those views read it with
/// `@Environment(RouteNavigator<Root>.self) var navigator: RouteNavigator<Root>?` or use it
/// through `RouteLink`.
///
/// The environment identifies a navigator by its type, so hosts with different route views never
/// share one, and the closest provider of the same route view wins.
///
/// A navigator stores the router's concrete history router; it is not a router protocol and
/// performs no type erasure. Every destination is validated as the router validates it, so a
/// destination from another route set is rejected with `RouteMatchError.foreignRoute`.
public final class RouteNavigator<RouteContent: View>: _RouteEnvironmentObject {
  public typealias ActiveMatchOptions = Router<RouteContent>.ActiveMatchOptions

  enum Storage {
    case path(HistoryRouter<RouteContent, BrowserHistory>)
    case hash(HistoryRouter<RouteContent, HashHistory<BrowserHistory>>)
  }

  let storage: Storage

  /// Created by `Router` and `HashRouter`. The navigator holds the router's state but not the
  /// router, so the two never form a reference cycle.
  init(storage: Storage) {
    self.storage = storage
  }

  /// The current location of the router.
  public var location: RouteLocation {
    switch storage {
    case .path(let router): router.location
    case .hash(let router): router.location
    }
  }

  /// The matched route stack from parent to leaf.
  public var matchedRoutes: [RouteHandle] {
    switch storage {
    case .path(let router): router.matchedRoutes
    case .hash(let router): router.matchedRoutes
    }
  }

  /// Returns the href for a destination in the router's mode, such as `/shop/products/7` or
  /// `#/shop/products/7`, including a path-mode router's base path.
  public func href(to destination: RouteDestination<RouteContent>) throws(RouteMatchError) -> String {
    switch storage {
    case .path(let router): try router.href(to: destination)
    case .hash(let router): try router.href(to: destination)
    }
  }

  /// Navigates to a destination, pushing a history entry unless `replace` is `true`.
  public func navigate(
    to destination: RouteDestination<RouteContent>,
    replace: Bool = false
  ) throws(RouteMatchError) {
    switch storage {
    case .path(let router): try router.navigate(to: destination, replace: replace)
    case .hash(let router): try router.navigate(to: destination, replace: replace)
    }
  }

  /// Replaces the current history entry with a destination.
  public func replace(to destination: RouteDestination<RouteContent>) throws(RouteMatchError) {
    try navigate(to: destination, replace: true)
  }

  /// Returns `true` when the current leaf route and path parameters equal the destination's.
  ///
  /// See `Router.isActive(_:includeQuery:includeHash:)`.
  public func isActive(
    _ destination: RouteDestination<RouteContent>,
    includeQuery: Bool = true,
    includeHash: Bool = false
  ) -> Bool {
    switch storage {
    case .path(let router):
      router.isActive(destination, includeQuery: includeQuery, includeHash: includeHash)
    case .hash(let router):
      router.isActive(destination, includeQuery: includeQuery, includeHash: includeHash)
    }
  }

  /// Returns `true` when the given route is active under the supplied matching options.
  ///
  /// Pass a mount or feature layout handle with `.descendant` to check whether the current
  /// route is inside it.
  public func isActive(_ route: RouteHandle, options: ActiveMatchOptions = .exact) -> Bool {
    switch storage {
    case .path(let router): router.isActive(route, options: options)
    case .hash(let router): router.isActive(route, options: options)
    }
  }

  /// `true` when the router accepts `destination` for client navigation.
  func accepts(_ destination: RouteDestination<RouteContent>) -> Bool {
    switch storage {
    case .path(let router): router.accepts(destination)
    case .hash(let router): router.accepts(destination)
    }
  }

  /// The anchor href of `destination` in the router's mode, without validating it.
  ///
  /// It equals `href(to:)` for every accepted destination, as the generated links' hrefs do.
  func linkHref(for destination: RouteDestination<RouteContent>) -> String {
    switch storage {
    case .path(let router): router.linkHref(for: destination)
    case .hash(let router): router.linkHref(for: destination)
    }
  }
}
