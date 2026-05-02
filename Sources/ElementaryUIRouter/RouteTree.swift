public struct RouteTree {
    let records: [CompiledRouteRecord]
    let notFoundRenderer: ((RouteNotFoundContext) -> Void)?
    let errorRenderer: ((RouteErrorContext) -> Void)?

    init(
        records: [CompiledRouteRecord],
        notFoundRenderer: ((RouteNotFoundContext) -> Void)?,
        errorRenderer: ((RouteErrorContext) -> Void)?
    ) {
        self.records = records
        self.notFoundRenderer = notFoundRenderer
        self.errorRenderer = errorRenderer
    }

    public func match(_ location: RouteLocation) -> RouteMatch? {
        for record in records {
            if let params = record.pattern.match(location.path) {
                return RouteMatch(route: record.handle, path: record.pattern.path, params: params)
            }
        }
        return nil
    }

    public func href(to route: RouteHandle, params: RouteParameters = RouteParameters(), query: RouteParameters = RouteParameters(), hash: String = "") throws(RouteMatchError) -> String {
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

    public func resolve(_ location: RouteLocation) -> RouteRenderResolution {
        guard let record = records.first(where: { $0.pattern.match(location.path) != nil }),
              let params = record.pattern.match(location.path)
        else {
            return .notFound(
                RouteNotFoundContext(
                    location: location,
                    query: QueryString.parse(location.queryString)
                )
            )
        }

        let match = RouteMatch(route: record.handle, path: record.pattern.path, params: params)
        let context = RouteContext(
            params: params,
            query: QueryString.parse(location.queryString),
            location: location,
            match: match
        )

        do throws(RouteValueError) {
            try record.render(context)
            return .matched(context)
        } catch {
            return .error(RouteErrorContext(error: error, routeContext: context))
        }
    }

    func render(_ location: RouteLocation) throws(RouterRenderError) {
        switch resolve(location) {
        case .matched:
            throw RouterRenderError.unavailableUntilElementaryUIExposesTypeErasedView
        case let .notFound(context):
            notFoundRenderer?(context)
            throw RouterRenderError.unavailableUntilElementaryUIExposesTypeErasedView
        case let .error(context):
            if let errorRenderer {
                errorRenderer(context)
                throw RouterRenderError.unavailableUntilElementaryUIExposesTypeErasedView
            }
            throw RouterRenderError.routeRenderFailed(context.error)
        }
    }
}
