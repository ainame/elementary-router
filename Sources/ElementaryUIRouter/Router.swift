import Reactivity

public enum NavigationState: Equatable, Sendable {
    case idle
    case navigating
}

@Reactive
public final class Router {
    public private(set) var location: RouteLocation
    public private(set) var matches: [RouteMatch]
    public private(set) var navigationState: NavigationState = .idle
    @ReactiveIgnored private let routes: RouteTree
    @ReactiveIgnored private let history: any RouterHistory
    @ReactiveIgnored private var subscription: HistorySubscription?

    public init(routes: RouteTree, history: any RouterHistory) {
        self.routes = routes
        self.history = history
        self.location = history.location
        if let match = routes.match(history.location) {
            self.matches = [match]
        } else {
            self.matches = []
        }

        self.subscription = history.listen { update in
            self.apply(update.location)
        }
    }

    deinit {
        subscription?.cancel()
    }

    public var currentMatch: RouteMatch? {
        matches.last
    }

    public func href(to route: RouteHandle, params: RouteParameters = RouteParameters(), query: RouteParameters = RouteParameters(), hash: String = "") throws(RouteMatchError) -> String {
        try routes.href(to: route, params: params, query: query, hash: hash)
    }

    public func navigate(to route: RouteHandle, params: RouteParameters = RouteParameters(), query: RouteParameters = RouteParameters(), hash: String = "", replace: Bool = false) throws(RouteMatchError) {
        let href = try routes.href(to: route, params: params, query: query, hash: hash)
        navigate(to: RouteLocation(url: href), replace: replace)
    }

    public func navigate(to location: RouteLocation, replace: Bool = false) {
        navigationState = .navigating
        if replace {
            history.replace(location)
        } else {
            history.push(location)
        }
        apply(location)
        navigationState = .idle
    }

    public func replace(to route: RouteHandle, params: RouteParameters = RouteParameters(), query: RouteParameters = RouteParameters(), hash: String = "") throws(RouteMatchError) {
        try navigate(to: route, params: params, query: query, hash: hash, replace: true)
    }

    public func back() {
        history.go(-1)
    }

    public func forward() {
        history.go(1)
    }

    public func isActive(_ route: RouteHandle) -> Bool {
        currentMatch?.route == route
    }

    public func resolveCurrentRoute() -> RouteRenderResolution {
        routes.resolve(location)
    }

    public func renderCurrentRoute() throws(RouterRenderError) {
        try routes.render(location)
    }

    private func apply(_ location: RouteLocation) {
        self.location = location
        if let match = routes.match(location) {
            self.matches = [match]
        } else {
            self.matches = []
        }
    }
}
