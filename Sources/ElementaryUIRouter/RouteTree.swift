public struct RouteTree {
    let records: [CompiledRouteRecord]

    init(records: [CompiledRouteRecord]) {
        self.records = records
    }

    public func match(_ location: RouteLocation) -> RouteMatch? {
        for record in records {
            if let params = record.pattern.match(location.path) {
                return RouteMatch(route: record.handle, path: record.pattern.path, params: params)
            }
        }
        return nil
    }

    public func href(to route: RouteHandle, params: RouteValues = RouteValues(), query: RouteValues = RouteValues(), hash: String = "") throws(RouteMatchError) -> String {
        guard let record = records.first(where: { $0.handle == route }) else {
            throw RouteMatchError.missingRequiredParameter(name: "route")
        }

        var href = try record.pattern.buildPath(params: params)
        let queryString = QueryString.stringify(query)
        if !queryString.isEmpty {
            href += "?" + queryString
        }
        let trimmedHash = RouteLocation.trimmedHash(hash)
        if !trimmedHash.isEmpty {
            href += "#" + URLCoding.encode(trimmedHash, spaceAsPlus: false)
        }
        return href
    }

    func render(_ context: RouteContext) throws(RouterRenderError) {
        guard records.contains(where: { $0.handle == context.match.route }) else {
            throw RouterRenderError.unavailableUntilElementaryUIExposesTypeErasedView
        }
        throw RouterRenderError.unavailableUntilElementaryUIExposesTypeErasedView
    }
}
