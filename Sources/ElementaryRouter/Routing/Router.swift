import ElementaryUI
import Reactivity

@Reactive
final class RouterState {
  var location: RouteLocation
  var matches: [RouteMatch]
  /// `true` when the document location is outside the router's base path. `location` is then
  /// the document location, and no route matches it.
  var isOutsideBasePath: Bool

  init(location: RouteLocation, matches: [RouteMatch], isOutsideBasePath: Bool) {
    self.location = location
    self.matches = matches
    self.isOutsideBasePath = isOutsideBasePath
  }

  convenience init<RouteContent: View>(
    document: RouteLocation,
    routes: RouteTree<RouteContent>,
    basePath: BasePath
  ) {
    if let location = basePath.routeLocation(in: document) {
      self.init(location: location, matches: routes._matches(location), isOutsideBasePath: false)
    } else {
      self.init(location: document, matches: [], isOutsideBasePath: true)
    }
  }

  func apply<RouteContent: View>(
    document: RouteLocation,
    routes: RouteTree<RouteContent>,
    basePath: BasePath
  ) {
    if let location = basePath.routeLocation(in: document) {
      self.location = location
      self.matches = routes._matches(location)
      self.isOutsideBasePath = false
    } else {
      self.location = document
      self.matches = []
      self.isOutsideBasePath = true
    }
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

  /// This router as seen by views that only know its route content type, such as the views of
  /// mounted features. Generated providers install it in the environment.
  public let navigator: RouteNavigator<RouteContent>

  /// Creates a path router for the given compiled route tree, served under `basePath`.
  ///
  /// Generated route sets pass the `basePath` declared by `@Routes(basePath:)`. Leading and
  /// trailing slashes are optional, and `""` or `"/"` mean the app is served from the origin
  /// root. With a base path such as `/SpeedMath`, the document path `/SpeedMath/users/42`
  /// matches the route `/users/42`, hrefs and history entries get the prefix, and a document
  /// path outside the base path renders the `@NotFound` fallback.
  ///
  /// The router observes browser history until it and its navigator are released.
  public convenience init(routes: RouteTree<RouteContent>, basePath: String = "") {
    self.init(routes: routes, history: BrowserHistory(), basePath: basePath)
  }

  init(routes: RouteTree<RouteContent>, history: BrowserHistory, basePath: String = "") {
    let storage = HistoryRouter(routes: routes, history: history, basePath: BasePath(basePath))
    self.storage = storage
    self.navigator = RouteNavigator(storage: .path(storage))
  }

  /// The normalized base path, such as `/SpeedMath`, or `""` when the app is served from the
  /// origin root.
  public var basePath: String {
    storage.basePath.value
  }

  /// Returns `true` when this router resolves exactly the compiled tree `routes`.
  ///
  /// Generated providers use this to reject a router built from a different route set.
  public func _uses(_ routes: RouteTree<RouteContent>) -> Bool {
    storage.routes._isSameTree(as: routes)
  }

  /// The current route location, relative to the base path.
  ///
  /// When the document location is outside the base path, this is the document location and no
  /// route matches.
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

  /// Returns `true` when this router can navigate to `destination`.
  ///
  /// A destination is accepted when this router's route set registered its route and the route
  /// still resolves its location. Generated links use this to choose client navigation.
  public func _accepts(_ destination: RouteDestination<RouteContent>) -> Bool {
    storage.accepts(destination)
  }

  /// Returns the href for a destination, such as `/users/42?tab=posts`, prefixed with the base
  /// path, such as `/SpeedMath/users/42?tab=posts`.
  ///
  /// Throws `RouteMatchError.foreignRoute` for a destination from another route set.
  public func href(to destination: RouteDestination<RouteContent>) throws(RouteMatchError) -> String {
    try storage.href(to: destination)
  }

  /// Navigates to a destination, pushing a history entry unless `replace` is `true`.
  ///
  /// Throws `RouteMatchError.foreignRoute` for a destination from another route set, without
  /// changing the location.
  public func navigate(
    to destination: RouteDestination<RouteContent>,
    replace: Bool = false
  ) throws(RouteMatchError) {
    try storage.navigate(to: destination, replace: replace)
  }

  /// Replaces the current history entry with a destination.
  public func replace(to destination: RouteDestination<RouteContent>) throws(RouteMatchError) {
    try storage.replace(to: destination)
  }

  /// Returns `true` when the current leaf route and path parameters equal the destination's.
  ///
  /// With `includeQuery`, every query value of the destination must also be present in the
  /// current location; omitted query defaults are not compared. With `includeHash`, the decoded
  /// fragments must be equal. Use the `RouteHandle` overload with `.descendant` to check
  /// enclosing layouts.
  public func isActive(
    _ destination: RouteDestination<RouteContent>,
    includeQuery: Bool = true,
    includeHash: Bool = false
  ) -> Bool {
    storage.isActive(destination, includeQuery: includeQuery, includeHash: includeHash)
  }

  /// Builds an href for a registered route handle and raw values.
  ///
  /// This is the untyped, low-level API. Prefer typed destinations from the generated route set.
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

  /// Navigates directly to a route location, which is relative to the base path.
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

  /// This router as seen by views that only know its route content type, such as the views of
  /// mounted features. Generated providers install it in the environment.
  public let navigator: RouteNavigator<RouteContent>

  /// Creates a hash router for the given compiled route tree.
  ///
  /// The router observes browser history until it and its navigator are released.
  public convenience init(routes: RouteTree<RouteContent>) {
    self.init(routes: routes, history: BrowserHistory())
  }

  init(routes: RouteTree<RouteContent>, history: BrowserHistory) {
    let storage = HistoryRouter(routes: routes, history: HashHistory(base: history))
    self.storage = storage
    self.navigator = RouteNavigator(storage: .hash(storage))
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

  /// Returns `true` when this router can navigate to `destination`.
  ///
  /// A destination is accepted when this router's route set registered its route and the route
  /// still resolves its location. Generated links use this to choose client navigation.
  public func _accepts(_ destination: RouteDestination<RouteContent>) -> Bool {
    storage.accepts(destination)
  }

  /// Returns the fragment href for a destination, such as `#/users/42?tab=posts`.
  ///
  /// The href resolves against the current document URL, so the app's base path and outer query
  /// string are preserved by normal clicks, modified clicks, and copied links. Do not declare a
  /// document `<base href>` element in hash-mode apps, because it changes that resolution.
  /// Throws `RouteMatchError.foreignRoute` for a destination from another route set.
  public func href(to destination: RouteDestination<RouteContent>) throws(RouteMatchError) -> String {
    try storage.href(to: destination)
  }

  /// Navigates to a destination, pushing a history entry unless `replace` is `true`.
  ///
  /// Throws `RouteMatchError.foreignRoute` for a destination from another route set, without
  /// changing the location.
  public func navigate(
    to destination: RouteDestination<RouteContent>,
    replace: Bool = false
  ) throws(RouteMatchError) {
    try storage.navigate(to: destination, replace: replace)
  }

  /// Replaces the current history entry with a destination.
  public func replace(to destination: RouteDestination<RouteContent>) throws(RouteMatchError) {
    try storage.replace(to: destination)
  }

  /// Returns `true` when the current leaf route and path parameters equal the destination's.
  ///
  /// With `includeQuery`, every query value of the destination must also be present in the
  /// current location; omitted query defaults are not compared. With `includeHash`, the decoded
  /// fragments must be equal.
  public func isActive(
    _ destination: RouteDestination<RouteContent>,
    includeQuery: Bool = true,
    includeHash: Bool = false
  ) -> Bool {
    storage.isActive(destination, includeQuery: includeQuery, includeHash: includeHash)
  }

  /// Builds a fragment href, such as `#/users/42?tab=posts`, for a registered route handle and
  /// raw values.
  ///
  /// This is the untyped, low-level API. Prefer typed destinations from the generated route set.
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
  /// The document path prefix of path-mode routers; hash-mode routers have none.
  let basePath: BasePath
  private let state: RouterState
  private let history: History
  private let subscription: HistorySubscription

  init(routes: RouteTree<RouteContent>, history: History, basePath: BasePath = .none) {
    let state = RouterState(document: history.location, routes: routes, basePath: basePath)
    self.routes = routes
    self.basePath = basePath
    self.history = history
    self.state = state

    // History notifications are the only path that updates `state`, so each push, replace, or
    // traversal is applied once. The listener captures the tree and state but not the router,
    // so the history never keeps the router alive.
    self.subscription = history.listen { update in
      state.apply(document: update.location, routes: routes, basePath: basePath)
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
    return history.href(for: basePath.documentLocation(for: RouteLocation(url: path)))
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

  func accepts(_ destination: RouteDestination<RouteContent>) -> Bool {
    do throws(RouteMatchError) {
      try routes._validate(destination)
      return true
    } catch {
      return false
    }
  }

  func href(to destination: RouteDestination<RouteContent>) throws(RouteMatchError) -> String {
    try routes._validate(destination)
    return linkHref(for: destination)
  }

  /// The anchor href of `destination`, without validating it.
  ///
  /// It equals `href(to:)` for every accepted destination, as the generated links' hrefs do.
  func linkHref(for destination: RouteDestination<RouteContent>) -> String {
    history.href(for: basePath.documentLocation(for: destination.location))
  }

  func navigate(
    to destination: RouteDestination<RouteContent>,
    replace: Bool = false
  ) throws(RouteMatchError) {
    try routes._validate(destination)
    navigate(to: destination.location, replace: replace)
  }

  func isActive(
    _ destination: RouteDestination<RouteContent>,
    includeQuery: Bool = true,
    includeHash: Bool = false
  ) -> Bool {
    // Handles compare by registration, so a destination from another route set never matches.
    guard let match = currentMatch, match.route == destination.route,
      match.params.containsAll(destination.params)
    else {
      return false
    }

    if includeQuery, !QueryString.parse(location.queryString).containsAll(destination.query) {
      return false
    }

    if includeHash, destination.hash != URLCoding.decode(location.hash, plusIsSpace: false) {
      return false
    }

    return true
  }

  func navigate(to location: RouteLocation, replace: Bool = false) {
    let document = basePath.documentLocation(for: location)
    if replace {
      history.replace(document)
    } else {
      history.push(document)
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

  func replace(to destination: RouteDestination<RouteContent>) throws(RouteMatchError) {
    try navigate(to: destination, replace: true)
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
    if state.isOutsideBasePath {
      return routes._notFound(location)
    }
    return routes._resolve(location)
  }

  func renderCurrentRoute() throws(RouterRenderError) -> RouteContent {
    if state.isOutsideBasePath {
      return try routes._renderNotFound(location)
    }
    return try routes._render(location)
  }
}

typealias MemoryRouter<RouteContent: View> = HistoryRouter<RouteContent, MemoryHistory>
