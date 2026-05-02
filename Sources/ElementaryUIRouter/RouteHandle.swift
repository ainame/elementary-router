public struct RouteID: Hashable, Equatable, Sendable {
    let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public struct RouteHandle: Hashable, Equatable, Sendable {
    public let id: RouteID

    public init(id: RouteID) {
        self.id = id
    }
}

public struct RouteMatch: Equatable, Sendable {
    public let route: RouteHandle
    public let path: String
    public let params: RouteValues

    public init(route: RouteHandle, path: String, params: RouteValues) {
        self.route = route
        self.path = path
        self.params = params
    }
}

public struct RouteContext: Sendable {
    public let params: RouteValues
    public let query: RouteValues
    public let location: RouteLocation
    public let match: RouteMatch

    public init(params: RouteValues, query: RouteValues, location: RouteLocation, match: RouteMatch) {
        self.params = params
        self.query = query
        self.location = location
        self.match = match
    }
}
