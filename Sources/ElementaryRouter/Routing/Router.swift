import ElementaryUI
import Reactivity

@Reactive
final class RouterState {
  var location: RouteLocation
  var matches: [RouteMatch]

  init(location: RouteLocation, matches: [RouteMatch]) {
    self.location = location
    self.matches = matches
  }

  func apply(location: RouteLocation, matches: [RouteMatch]) {
    self.location = location
    self.matches = matches
  }
}

/// A browser path router backed by `history.pushState`.
public final class Router<RouteContent: View> {
  /// Controls how `isActive` evaluates a candidate route against the current location.
  public struct ActiveMatchOptions: Equatable, Sendable {
    /// When `true`, parent routes count as active when a descendant route is currently matched.
    public var includeDescendants: Bool
    /// Optional path parameters that must match for the route to be considered active.
    public var params: RouteValues?
    /// Optional query values that must match for the route to be considered active.
    public var query: RouteValues?
    /// Optional hash fragment that must match for the route to be considered active.
    public var hash: String?

    /// Creates a new active-route comparison policy.
    public init(
      includeDescendants: Bool = false,
      params: RouteValues? = nil,
      query: RouteValues? = nil,
      hash: String? = nil
    ) {
      self.includeDescendants = includeDescendants
      self.params = params
      self.query = query
      self.hash = hash
    }

    /// Matches only the exact route, params, query, and hash provided.
    public static var exact: Self {
      Self()
    }

    /// Matches the route or any currently active descendant of that route.
    public static var descendant: Self {
      Self(includeDescendants: true)
    }
  }

  private let storage: HistoryRouter<RouteContent, BrowserHistory>

  /// Creates a path router for the given compiled route tree.
  ///
  /// The router observes browser history until it is released.
  public convenience init(routes: RouteTree<RouteContent>) {
    self.init(routes: routes, history: BrowserHistory())
  }

  init(routes: RouteTree<RouteContent>, history: BrowserHistory) {
    self.storage = HistoryRouter(routes: routes, history: history)
  }

  /// Returns `true` when this router resolves exactly the compiled tree `routes`.
  ///
  /// Generated providers use this to reject a router built from a different route set.
  public func _uses(_ routes: RouteTree<RouteContent>) -> Bool {
    storage.routes._isSameTree(as: routes)
  }

  /// The current browser location.
  public var location: RouteLocation {
    storage.location
  }

  /// The matched route stack from parent to leaf.
  public var matchedRoutes: [RouteHandle] {
    storage.matches.map { $0.route }
  }

  /// The currently matched leaf route, if any.
  public var currentRoute: RouteHandle? {
    storage.currentMatch?.route
  }

  /// The current leaf route's decoded path parameters, if any.
  public var currentParams: RouteValues? {
    storage.currentMatch?.params
  }

  /// Builds an href for a registered route handle.
  public func href(
    to route: RouteHandle,
    params: RouteValues = RouteValues(),
    query: RouteValues = RouteValues(),
    hash: String = ""
  ) throws(RouteMatchError) -> String {
    try storage.href(to: route, params: params, query: query, hash: hash)
  }

  /// Navigates to a registered route handle.
  public func navigate(
    to route: RouteHandle,
    params: RouteValues = RouteValues(),
    query: RouteValues = RouteValues(),
    hash: String = "",
    replace: Bool = false
  ) throws(RouteMatchError) {
    try storage.navigate(to: route, params: params, query: query, hash: hash, replace: replace)
  }

  /// Navigates directly to a raw browser location.
  public func navigate(to location: RouteLocation, replace: Bool = false) {
    storage.navigate(to: location, replace: replace)
  }

  /// Replaces the current browser history entry with a registered route handle.
  public func replace(
    to route: RouteHandle,
    params: RouteValues = RouteValues(),
    query: RouteValues = RouteValues(),
    hash: String = ""
  ) throws(RouteMatchError) {
    try storage.replace(to: route, params: params, query: query, hash: hash)
  }

  /// Navigates one browser history entry backward.
  public func back() {
    storage.back()
  }

  /// Navigates one browser history entry forward.
  public func forward() {
    storage.forward()
  }

  /// Returns `true` when the given route is active under the supplied matching options.
  public func isActive(
    _ route: RouteHandle,
    options: ActiveMatchOptions = .exact
  ) -> Bool {
    storage.isActive(route, options: options)
  }

  /// Resolves and renders the current route.
  public func renderCurrentRoute() throws(RouterRenderError) -> RouteContent {
    try storage.renderCurrentRoute()
  }
}

/// A browser router that stores route state in the URL hash fragment.
public final class HashRouter<RouteContent: View> {
  public typealias ActiveMatchOptions = Router<RouteContent>.ActiveMatchOptions

  private let storage: HistoryRouter<RouteContent, HashHistory<BrowserHistory>>

  /// Creates a hash router for the given compiled route tree.
  ///
  /// The router observes browser history until it is released.
  public convenience init(routes: RouteTree<RouteContent>) {
    self.init(routes: routes, history: BrowserHistory())
  }

  init(routes: RouteTree<RouteContent>, history: BrowserHistory) {
    self.storage = HistoryRouter(routes: routes, history: HashHistory(base: history))
  }

  /// Returns `true` when this router resolves exactly the compiled tree `routes`.
  ///
  /// Generated providers use this to reject a router built from a different route set.
  public func _uses(_ routes: RouteTree<RouteContent>) -> Bool {
    storage.routes._isSameTree(as: routes)
  }

  /// The current browser location.
  public var location: RouteLocation {
    storage.location
  }

  /// The matched route stack from parent to leaf.
  public var matchedRoutes: [RouteHandle] {
    storage.matches.map { $0.route }
  }

  /// The currently matched leaf route, if any.
  public var currentRoute: RouteHandle? {
    storage.currentMatch?.route
  }

  /// The current leaf route's decoded path parameters, if any.
  public var currentParams: RouteValues? {
    storage.currentMatch?.params
  }

  /// Builds a fragment href, such as `#/users/42?tab=posts`, for a registered route handle.
  ///
  /// The href resolves against the current document URL, so the app's base path and outer query
  /// string are preserved by normal clicks, modified clicks, and copied links. Do not declare a
  /// document `<base href>` element in hash-mode apps, because it changes that resolution.
  public func href(
    to route: RouteHandle,
    params: RouteValues = RouteValues(),
    query: RouteValues = RouteValues(),
    hash: String = ""
  ) throws(RouteMatchError) -> String {
    try storage.href(to: route, params: params, query: query, hash: hash)
  }

  /// Navigates to a registered route handle.
  public func navigate(
    to route: RouteHandle,
    params: RouteValues = RouteValues(),
    query: RouteValues = RouteValues(),
    hash: String = "",
    replace: Bool = false
  ) throws(RouteMatchError) {
    try storage.navigate(to: route, params: params, query: query, hash: hash, replace: replace)
  }

  /// Navigates directly to a route location stored in the URL hash fragment.
  public func navigate(to location: RouteLocation, replace: Bool = false) {
    storage.navigate(to: location, replace: replace)
  }

  /// Replaces the current browser history entry with a registered route handle.
  public func replace(
    to route: RouteHandle,
    params: RouteValues = RouteValues(),
    query: RouteValues = RouteValues(),
    hash: String = ""
  ) throws(RouteMatchError) {
    try storage.replace(to: route, params: params, query: query, hash: hash)
  }

  /// Navigates one browser history entry backward.
  public func back() {
    storage.back()
  }

  /// Navigates one browser history entry forward.
  public func forward() {
    storage.forward()
  }

  /// Returns `true` when the given route is active under the supplied matching options.
  public func isActive(
    _ route: RouteHandle,
    options: ActiveMatchOptions = .exact
  ) -> Bool {
    storage.isActive(route, options: options)
  }

  /// Resolves and renders the current route.
  public func renderCurrentRoute() throws(RouterRenderError) -> RouteContent {
    try storage.renderCurrentRoute()
  }
}

final class HistoryRouter<RouteContent: View, History: RouterHistory> {
  typealias ActiveMatchOptions = Router<RouteContent>.ActiveMatchOptions

  let routes: RouteTree<RouteContent>
  private let state: RouterState
  private let history: History
  private let subscription: HistorySubscription

  init(routes: RouteTree<RouteContent>, history: History) {
    let state = RouterState(location: history.location, matches: routes._matches(history.location))
    self.routes = routes
    self.history = history
    self.state = state

    // History notifications are the only path that updates `state`, so each push, replace, or
    // traversal is applied once. The listener captures the tree and state but not the router,
    // so the history never keeps the router alive.
    self.subscription = history.listen { update in
      state.apply(location: update.location, matches: routes._matches(update.location))
    }
  }

  deinit {
    subscription.cancel()
  }

  var location: RouteLocation {
    state.location
  }

  var matches: [RouteMatch] {
    state.matches
  }

  var currentMatch: RouteMatch? {
    matches.last
  }

  var matchedRoutes: [RouteHandle] {
    matches.map { $0.route }
  }

  var currentRoute: RouteHandle? {
    currentMatch?.route
  }

  var currentParams: RouteValues? {
    currentMatch?.params
  }

  func href(
    to route: RouteHandle,
    params: RouteValues = RouteValues(),
    query: RouteValues = RouteValues(),
    hash: String = ""
  ) throws(RouteMatchError) -> String {
    let path = try routes._href(to: route, params: params, query: query, hash: hash)
    return history.href(for: RouteLocation(url: path))
  }

  func navigate(
    to route: RouteHandle,
    params: RouteValues = RouteValues(),
    query: RouteValues = RouteValues(),
    hash: String = "",
    replace: Bool = false
  ) throws(RouteMatchError) {
    let href = try routes._href(to: route, params: params, query: query, hash: hash)
    navigate(to: RouteLocation(url: href), replace: replace)
  }

  func navigate(to location: RouteLocation, replace: Bool = false) {
    if replace {
      history.replace(location)
    } else {
      history.push(location)
    }
  }

  func replace(
    to route: RouteHandle,
    params: RouteValues = RouteValues(),
    query: RouteValues = RouteValues(),
    hash: String = ""
  ) throws(RouteMatchError) {
    try navigate(to: route, params: params, query: query, hash: hash, replace: true)
  }

  func back() {
    history.go(-1)
  }

  func forward() {
    history.go(1)
  }

  func isActive(
    _ route: RouteHandle,
    options: ActiveMatchOptions = .exact
  ) -> Bool {
    let matchedRoute =
      options.includeDescendants
      ? matches.first { $0.route == route }
      : currentMatch.flatMap { $0.route == route ? $0 : nil }

    guard let match = matchedRoute else {
      return false
    }

    if let expectedParams = options.params,
      !match.params.containsAll(expectedParams)
    {
      return false
    }

    if let expectedQuery = options.query,
      !QueryString.parse(location.queryString).containsAll(expectedQuery)
    {
      return false
    }

    // `href(to:)` percent-encodes the hash it is given, so compare with the decoded fragment.
    if let expectedHash = options.hash,
      RouteLocation.trimmedHash(expectedHash) != URLCoding.decode(location.hash, plusIsSpace: false)
    {
      return false
    }

    return true
  }

  func resolveCurrentRoute() -> RouteTree<RouteContent>.Resolution {
    routes._resolve(location)
  }

  func renderCurrentRoute() throws(RouterRenderError) -> RouteContent {
    try routes._render(location)
  }
}

typealias MemoryRouter<RouteContent: View> = HistoryRouter<RouteContent, MemoryHistory>
