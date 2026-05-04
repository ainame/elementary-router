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

public final class Router<RouteContent: View> {
  public struct ActiveMatchOptions: Equatable, Sendable {
    public var includeDescendants: Bool
    public var params: RouteParameters?
    public var query: RouteParameters?
    public var hash: String?

    public init(
      includeDescendants: Bool = false,
      params: RouteParameters? = nil,
      query: RouteParameters? = nil,
      hash: String? = nil
    ) {
      self.includeDescendants = includeDescendants
      self.params = params
      self.query = query
      self.hash = hash
    }

    public static var exact: Self {
      Self()
    }

    public static var descendant: Self {
      Self(includeDescendants: true)
    }
  }

  private let storage: HistoryRouter<RouteContent, BrowserHistory>

  public init(routes: RouteTree<RouteContent>) {
    self.storage = HistoryRouter(routes: routes, history: BrowserHistory())
  }

  public var location: RouteLocation {
    storage.location
  }

  public var matchedRoutes: [RouteHandle] {
    storage.matches.map(\.route)
  }

  public var currentRoute: RouteHandle? {
    storage.currentMatch?.route
  }

  public var currentParams: RouteParameters? {
    storage.currentMatch?.params
  }

  public func href(
    to route: RouteHandle,
    params: RouteParameters = RouteParameters(),
    query: RouteParameters = RouteParameters(),
    hash: String = ""
  ) throws(RouteMatchError) -> String {
    try storage.href(to: route, params: params, query: query, hash: hash)
  }

  public func navigate(
    to route: RouteHandle,
    params: RouteParameters = RouteParameters(),
    query: RouteParameters = RouteParameters(),
    hash: String = "",
    replace: Bool = false
  ) throws(RouteMatchError) {
    try storage.navigate(to: route, params: params, query: query, hash: hash, replace: replace)
  }

  public func navigate(to location: RouteLocation, replace: Bool = false) {
    storage.navigate(to: location, replace: replace)
  }

  public func replace(
    to route: RouteHandle,
    params: RouteParameters = RouteParameters(),
    query: RouteParameters = RouteParameters(),
    hash: String = ""
  ) throws(RouteMatchError) {
    try storage.replace(to: route, params: params, query: query, hash: hash)
  }

  public func back() {
    storage.back()
  }

  public func forward() {
    storage.forward()
  }

  public func isActive(
    _ route: RouteHandle,
    options: ActiveMatchOptions = .exact
  ) -> Bool {
    storage.isActive(route, options: options)
  }

  public func renderCurrentRoute() throws(RouterRenderError) -> RouteContent {
    try storage.renderCurrentRoute()
  }
}

public final class HashRouter<RouteContent: View> {
  public typealias ActiveMatchOptions = Router<RouteContent>.ActiveMatchOptions

  private let storage: HistoryRouter<RouteContent, HashHistory>

  public init(routes: RouteTree<RouteContent>) {
    self.storage = HistoryRouter(routes: routes, history: HashHistory())
  }

  public var location: RouteLocation {
    storage.location
  }

  public var matchedRoutes: [RouteHandle] {
    storage.matches.map(\.route)
  }

  public var currentRoute: RouteHandle? {
    storage.currentMatch?.route
  }

  public var currentParams: RouteParameters? {
    storage.currentMatch?.params
  }

  public func href(
    to route: RouteHandle,
    params: RouteParameters = RouteParameters(),
    query: RouteParameters = RouteParameters(),
    hash: String = ""
  ) throws(RouteMatchError) -> String {
    try storage.href(to: route, params: params, query: query, hash: hash)
  }

  public func navigate(
    to route: RouteHandle,
    params: RouteParameters = RouteParameters(),
    query: RouteParameters = RouteParameters(),
    hash: String = "",
    replace: Bool = false
  ) throws(RouteMatchError) {
    try storage.navigate(to: route, params: params, query: query, hash: hash, replace: replace)
  }

  public func navigate(to location: RouteLocation, replace: Bool = false) {
    storage.navigate(to: location, replace: replace)
  }

  public func replace(
    to route: RouteHandle,
    params: RouteParameters = RouteParameters(),
    query: RouteParameters = RouteParameters(),
    hash: String = ""
  ) throws(RouteMatchError) {
    try storage.replace(to: route, params: params, query: query, hash: hash)
  }

  public func back() {
    storage.back()
  }

  public func forward() {
    storage.forward()
  }

  public func isActive(
    _ route: RouteHandle,
    options: ActiveMatchOptions = .exact
  ) -> Bool {
    storage.isActive(route, options: options)
  }

  public func renderCurrentRoute() throws(RouterRenderError) -> RouteContent {
    try storage.renderCurrentRoute()
  }
}

final class HistoryRouter<RouteContent: View, History: RouterHistory> {
  typealias ActiveMatchOptions = Router<RouteContent>.ActiveMatchOptions

  private let state: RouterState
  private let routes: RouteTree<RouteContent>
  private let history: History
  private var subscription: HistorySubscription?

  init(routes: RouteTree<RouteContent>, history: History) {
    self.routes = routes
    self.history = history
    self.state = RouterState(location: history.location, matches: routes._matches(history.location))

    self.subscription = history.listen { update in
      self.apply(update.location)
    }
  }

  deinit {
    subscription?.cancel()
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
    matches.map(\.route)
  }

  var currentRoute: RouteHandle? {
    currentMatch?.route
  }

  var currentParams: RouteParameters? {
    currentMatch?.params
  }

  func href(
    to route: RouteHandle,
    params: RouteParameters = RouteParameters(),
    query: RouteParameters = RouteParameters(),
    hash: String = ""
  ) throws(RouteMatchError) -> String {
    try routes._href(to: route, params: params, query: query, hash: hash)
  }

  func navigate(
    to route: RouteHandle,
    params: RouteParameters = RouteParameters(),
    query: RouteParameters = RouteParameters(),
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
    apply(location)
  }

  func replace(
    to route: RouteHandle,
    params: RouteParameters = RouteParameters(),
    query: RouteParameters = RouteParameters(),
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

    if let expectedHash = options.hash,
      RouteLocation.trimmedHash(expectedHash) != location.hash
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

  private func apply(_ location: RouteLocation) {
    state.apply(location: location, matches: routes._matches(location))
  }
}

typealias MemoryRouter<RouteContent: View> = HistoryRouter<RouteContent, MemoryHistory>
