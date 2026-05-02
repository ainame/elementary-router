import ElementaryUI
import Reactivity

public enum NavigationState: Equatable, Sendable {
  case idle
  case navigating
}

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

@Reactive
public final class RouterState {
  public private(set) var location: RouteLocation
  public private(set) var matches: [RouteMatch]
  public private(set) var navigationState: NavigationState = .idle

  init(location: RouteLocation, matches: [RouteMatch]) {
    self.location = location
    self.matches = matches
  }

  func startNavigation() {
    navigationState = .navigating
  }

  func finishNavigation() {
    navigationState = .idle
  }

  func apply(location: RouteLocation, matches: [RouteMatch]) {
    self.location = location
    self.matches = matches
  }
}

public final class Router<RouteContent: View> {
  private let state: RouterState
  private let routes: RouteTree<RouteContent>
  private let history: any RouterHistory
  private var subscription: HistorySubscription?

  public init(routes: RouteTree<RouteContent>, history: any RouterHistory) {
    self.routes = routes
    self.history = history
    self.state = RouterState(location: history.location, matches: routes.matches(history.location))

    self.subscription = history.listen { update in
      self.apply(update.location)
    }
  }

  deinit {
    subscription?.cancel()
  }

  public var location: RouteLocation {
    state.location
  }

  public var matches: [RouteMatch] {
    state.matches
  }

  public var navigationState: NavigationState {
    state.navigationState
  }

  public var currentMatch: RouteMatch? {
    matches.last
  }

  public func href(
    to route: RouteHandle,
    params: RouteParameters = RouteParameters(),
    query: RouteParameters = RouteParameters(),
    hash: String = ""
  ) throws(RouteMatchError) -> String {
    try routes.href(to: route, params: params, query: query, hash: hash)
  }

  public func navigate(
    to route: RouteHandle,
    params: RouteParameters = RouteParameters(),
    query: RouteParameters = RouteParameters(),
    hash: String = "",
    replace: Bool = false
  ) throws(RouteMatchError) {
    let href = try routes.href(to: route, params: params, query: query, hash: hash)
    navigate(to: RouteLocation(url: href), replace: replace)
  }

  public func navigate(to location: RouteLocation, replace: Bool = false) {
    state.startNavigation()
    if replace {
      history.replace(location)
    } else {
      history.push(location)
    }
    apply(location)
    state.finishNavigation()
  }

  public func replace(
    to route: RouteHandle,
    params: RouteParameters = RouteParameters(),
    query: RouteParameters = RouteParameters(),
    hash: String = ""
  ) throws(RouteMatchError) {
    try navigate(to: route, params: params, query: query, hash: hash, replace: true)
  }

  public func back() {
    history.go(-1)
  }

  public func forward() {
    history.go(1)
  }

  public func isActive(
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

  public func resolveCurrentRoute() -> RouteRenderResolution {
    routes.resolve(location)
  }

  public func renderCurrentRoute() throws(RouterRenderError) -> RouteContent {
    try routes.render(location)
  }

  private func apply(_ location: RouteLocation) {
    state.apply(location: location, matches: routes.matches(location))
  }
}

extension Router: RouterNavigation {}
